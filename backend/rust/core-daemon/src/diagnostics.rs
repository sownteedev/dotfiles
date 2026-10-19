use crate::command::{command_path, run_bounded};
use crate::job::JobRegistry;
use anyhow::{Context, Result, bail};
use serde::Deserialize;
use serde_json::{Value, json};
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::task;
use tokio_util::sync::CancellationToken;

const COMMAND_OUTPUT_LIMIT: usize = 64 * 1024;
const SERVICE_OUTPUT_LIMIT: usize = 1024 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(4);
const SERVICE_ACTION_TIMEOUT: Duration = Duration::from_secs(120);
const DEPENDENCIES: &[(&str, &str, bool)] = &[
    ("quickshell", "Shell runtime", true),
    ("niri", "Compositor", true),
    ("swayidle", "Idle and power policy", true),
    ("cliphist", "Clipboard history", true),
    ("wl-copy", "Wayland clipboard", true),
    ("gpu-screen-recorder", "Screen recording", false),
    ("matugen", "Dynamic colors", false),
    ("ffmpeg", "Video thumbnails", false),
    ("magick", "Image thumbnails", false),
    ("linux-wallpaperengine", "Wallpaper Engine playback", false),
    ("steamcmd", "Workshop downloads", false),
];
const SERVICES: &[&str] = &[
    "sownteeshell-idle.service",
    "sownteeshell-caffeine-inhibitor.service",
];

#[derive(Clone)]
pub struct DiagnosticsBackend {
    jobs: JobRegistry,
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DiagnosticsParams {
    #[serde(default)]
    scope: String,
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ServiceActionParams {
    #[serde(default)]
    action: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    scope: ServiceScope,
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "lowercase")]
enum ServiceScope {
    #[default]
    User,
    System,
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct StartupActionParams {
    #[serde(default)]
    path: String,
    #[serde(default)]
    enabled: bool,
}

struct CacheScope {
    label: &'static str,
    path: PathBuf,
    scope: &'static str,
}

impl DiagnosticsBackend {
    pub fn new(jobs: JobRegistry) -> Self {
        Self { jobs }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("diagnostics.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();
        let result = match method {
            "diagnostics.snapshot" => snapshot(cancellation).await?,
            "diagnostics.serviceAction" => {
                let params: ServiceActionParams =
                    serde_json::from_value(params).context("decode service action")?;
                service_action(&params, cancellation).await?
            }
            "diagnostics.startupAction" => {
                let params: StartupActionParams =
                    serde_json::from_value(params).context("decode startup action")?;
                startup_action(&params).await
            }
            "diagnostics.clear" => {
                let params: DiagnosticsParams =
                    serde_json::from_value(params).context("decode diagnostics request")?;
                match clear_cache(&params.scope).await {
                    Ok(()) => json!({
                        "ok": true,
                        "message": format!("Cleared {} cache", params.scope),
                    }),
                    Err(error) => json!({"ok": false, "message": error.to_string()}),
                }
            }
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}

async fn snapshot(cancellation: CancellationToken) -> Result<Value> {
    let dependencies = DEPENDENCIES
        .iter()
        .map(|(name, description, required)| {
            json!({
                "name": name,
                "description": description,
                "required": required,
                "available": command_path(name).is_some(),
            })
        })
        .collect::<Vec<_>>();

    let scopes = cache_scopes();
    let size_scopes = scopes
        .iter()
        .map(|scope| (scope.scope, scope.label, scope.path.clone()))
        .collect::<Vec<_>>();
    let caches = task::spawn_blocking(move || {
        size_scopes
            .into_iter()
            .map(|(scope, label, path)| {
                json!({
                    "scope": scope,
                    "label": label,
                    "path": path,
                    "bytes": directory_size(&path),
                })
            })
            .collect::<Vec<_>>()
    })
    .await
    .context("join diagnostics cache scan")?;

    let (user_services, system_services) = tokio::join!(
        service_snapshot(true, cancellation.clone()),
        service_snapshot(false, cancellation.clone())
    );
    let startup_apps = task::spawn_blocking(startup_app_snapshot)
        .await
        .context("join startup app scan")?;

    let mut legacy_services = Vec::new();
    for unit in SERVICES {
        legacy_services.push(json!({
            "name": unit,
            "state": unit_state(unit, cancellation.clone()).await,
        }));
    }
    Ok(json!({
        "ok": true,
        "dependencies": dependencies,
        "caches": caches,
        "services": legacy_services,
        "startupApps": startup_apps,
        "userServices": user_services,
        "systemServices": system_services,
    }))
}

async fn service_snapshot(user: bool, cancellation: CancellationToken) -> Vec<Value> {
    let Some(systemctl) = command_path("systemctl") else {
        return Vec::new();
    };
    let scope = if user { "--user" } else { "--system" };
    let Ok(output) = run_bounded(
        &systemctl,
        &[
            scope,
            "show",
            "--type=service",
            "--all",
            "--no-pager",
            "-p",
            "Id",
            "-p",
            "Description",
            "-p",
            "ActiveState",
            "-p",
            "SubState",
            "-p",
            "UnitFileState",
            "-p",
            "MainPID",
            "-p",
            "MemoryCurrent",
            "-p",
            "ActiveEnterTimestamp",
        ],
        COMMAND_TIMEOUT,
        cancellation,
        SERVICE_OUTPUT_LIMIT,
    )
    .await
    else {
        return Vec::new();
    };

    parse_service_snapshot(&String::from_utf8_lossy(&output.stdout), user)
}

fn parse_service_snapshot(output: &str, user: bool) -> Vec<Value> {
    let mut services = Vec::new();
    let mut current = BTreeMap::<String, String>::new();
    for line in output.lines().chain(std::iter::once("")) {
        if line.is_empty() {
            if let Some(service) = service_value(&current, user) {
                services.push(service);
            }
            current.clear();
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            current.insert(key.to_string(), value.to_string());
        }
    }
    services
}

fn service_value(values: &BTreeMap<String, String>, user: bool) -> Option<Value> {
    let name = values.get("Id")?.to_string();
    if !name.ends_with(".service") {
        return None;
    }
    if name.starts_with("sownteeshell-") {
        return None;
    }
    let state = values
        .get("ActiveState")
        .cloned()
        .unwrap_or_else(|| "inactive".into());
    let startup = values
        .get("UnitFileState")
        .cloned()
        .unwrap_or_else(|| "unknown".into());
    let memory = values
        .get("MemoryCurrent")
        .and_then(|value| value.parse::<u64>().ok());
    let pid = values
        .get("MainPID")
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|value| *value > 0);
    Some(json!({
        "name": name,
        "description": values.get("Description").cloned().unwrap_or_default(),
        "state": state,
        "subState": values.get("SubState").cloned().unwrap_or_default(),
        "startup": startup,
        "pid": pid,
        "memory": memory,
        "startedAt": values.get("ActiveEnterTimestamp").cloned().unwrap_or_default(),
        "scope": if user { "user" } else { "system" },
        "manageable": true,
    }))
}

fn startup_app_snapshot() -> Vec<Value> {
    let Some(home) = env::var_os("HOME").map(PathBuf::from) else {
        return Vec::new();
    };
    let user_directory = home.join(".config/autostart");
    let system_directory = PathBuf::from("/etc/xdg/autostart");
    let mut user_entries = desktop_entries(&user_directory);
    let system_entries = desktop_entries(&system_directory);
    let mut apps = Vec::new();

    for (file_name, (system_path, system_fields)) in system_entries {
        if let Some((user_path, user_fields)) = user_entries.remove(&file_name) {
            if user_fields
                .get("X-SownteeShell-System-Override")
                .is_some_and(|value| value.eq_ignore_ascii_case("true"))
            {
                apps.push(startup_app_value(
                    &file_name,
                    &system_path,
                    &system_fields,
                    "system",
                    desktop_enabled(&user_fields),
                ));
            } else {
                apps.push(startup_app_value(
                    &file_name,
                    &user_path,
                    &user_fields,
                    "user",
                    desktop_enabled(&user_fields),
                ));
            }
        } else {
            apps.push(startup_app_value(
                &file_name,
                &system_path,
                &system_fields,
                "system",
                desktop_enabled(&system_fields),
            ));
        }
    }

    for (file_name, (path, fields)) in user_entries {
        apps.push(startup_app_value(
            &file_name,
            &path,
            &fields,
            "user",
            desktop_enabled(&fields),
        ));
    }
    apps.sort_by(|left, right| left["name"].as_str().cmp(&right["name"].as_str()));
    apps
}

fn desktop_entries(directory: &Path) -> BTreeMap<String, (PathBuf, BTreeMap<String, String>)> {
    let mut entries = BTreeMap::new();
    let Ok(directory_entries) = fs::read_dir(directory) else {
        return entries;
    };
    for entry in directory_entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|value| value.to_str()) != Some("desktop") {
            continue;
        }
        let Ok(text) = fs::read_to_string(&path) else {
            continue;
        };
        let file_name = path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or_default()
            .to_string();
        entries.insert(file_name, (path, desktop_fields(&text)));
    }
    entries
}

fn desktop_enabled(fields: &BTreeMap<String, String>) -> bool {
    !fields
        .get("Hidden")
        .is_some_and(|value| value.eq_ignore_ascii_case("true"))
        && !fields
            .get("X-GNOME-Autostart-enabled")
            .is_some_and(|value| value.eq_ignore_ascii_case("false"))
}

fn startup_app_value(
    file_name: &str,
    path: &Path,
    fields: &BTreeMap<String, String>,
    scope: &str,
    enabled: bool,
) -> Value {
    json!({
        "name": fields.get("Name").cloned().unwrap_or_else(|| file_name.trim_end_matches(".desktop").into()),
        "file": file_name,
        "path": path,
        "exec": fields.get("Exec").cloned().unwrap_or_default(),
        "scope": scope,
        "enabled": enabled,
    })
}

fn desktop_fields(text: &str) -> BTreeMap<String, String> {
    text.lines()
        .filter_map(|line| line.split_once('='))
        .filter(|(key, _)| {
            [
                "Name",
                "Exec",
                "Hidden",
                "X-GNOME-Autostart-enabled",
                "X-SownteeShell-System-Override",
            ]
            .contains(key)
        })
        .map(|(key, value)| (key.to_string(), value.trim().to_string()))
        .collect()
}

fn service_action_arguments(params: &ServiceActionParams) -> Result<Vec<&str>> {
    let action = params.action.trim();
    let name = params.name.trim();
    if !["start", "stop", "restart", "enable", "disable"].contains(&action)
        || !name.ends_with(".service")
        || name.len() <= ".service".len()
        || name.len() > 255
        || name.starts_with('-')
        || name.starts_with("sownteeshell-")
        || !name
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || b"-_.:@\\".contains(&byte))
    {
        bail!("Invalid service action");
    }
    let scope = match params.scope {
        ServiceScope::User => "--user",
        ServiceScope::System => "--system",
    };
    Ok(vec![scope, "--no-pager", action, "--", name])
}

async fn service_action(
    params: &ServiceActionParams,
    cancellation: CancellationToken,
) -> Result<Value> {
    let arguments = match service_action_arguments(params) {
        Ok(arguments) => arguments,
        Err(error) => return Ok(json!({"ok": false, "message": error.to_string()})),
    };
    let Some(systemctl) = command_path("systemctl") else {
        return Ok(json!({"ok": false, "message": "systemctl is unavailable"}));
    };
    let output = run_bounded(
        &systemctl,
        &arguments,
        SERVICE_ACTION_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await;
    match output {
        Ok(output) if output.status.success() => Ok(json!({
            "ok": true,
            "message": format!("{}: {} completed", params.name, params.action),
        })),
        Ok(output) => Ok(json!({
            "ok": false,
            "message": String::from_utf8_lossy(&output.stderr).trim().to_string()
        })),
        Err(error) => Ok(json!({"ok": false, "message": error.to_string()})),
    }
}

async fn startup_action(params: &StartupActionParams) -> Value {
    let Some(home) = env::var_os("HOME").map(PathBuf::from) else {
        return json!({"ok": false, "message": "Home directory is unavailable"});
    };
    let directory = home.join(".config/autostart");
    let system_directory = PathBuf::from("/etc/xdg/autostart");
    let path = PathBuf::from(&params.path);
    let is_user_entry = path.strip_prefix(&directory).is_ok();
    let is_system_entry = path.strip_prefix(&system_directory).is_ok();
    if !is_user_entry && !is_system_entry {
        return json!({"ok": false, "message": "Only user or system startup apps can be changed"});
    }
    let base_directory = if is_user_entry {
        &directory
    } else {
        &system_directory
    };
    let Ok(relative) = path.strip_prefix(base_directory) else {
        return json!({"ok": false, "message": "Invalid startup entry"});
    };
    if relative.components().count() != 1
        || path.extension().and_then(|value| value.to_str()) != Some("desktop")
    {
        return json!({"ok": false, "message": "Invalid startup entry"});
    }
    let Ok(metadata) = fs::symlink_metadata(&path) else {
        return json!({"ok": false, "message": "Startup entry was not found"});
    };
    if metadata.file_type().is_symlink() {
        return json!({"ok": false, "message": "Refusing to edit a symlink"});
    }
    let Ok(text) = fs::read_to_string(&path) else {
        return json!({"ok": false, "message": "Could not read startup entry"});
    };
    if is_system_entry {
        let file_name = relative
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or_default();
        let override_path = directory.join(file_name);
        if params.enabled {
            let Ok(override_text) = fs::read_to_string(&override_path) else {
                return json!({"ok": true, "message": "Startup override was already enabled"});
            };
            let fields = desktop_fields(&override_text);
            if !fields
                .get("X-SownteeShell-System-Override")
                .is_some_and(|value| value.eq_ignore_ascii_case("true"))
            {
                return json!({"ok": false, "message": "A user startup override already exists"});
            }
            return match fs::remove_file(&override_path) {
                Ok(()) => json!({"ok": true, "message": "System startup override removed"}),
                Err(error) => json!({"ok": false, "message": error.to_string()}),
            };
        }

        if let Ok(existing) = fs::symlink_metadata(&override_path) {
            if existing.file_type().is_symlink() {
                return json!({"ok": false, "message": "Refusing to edit a symlink"});
            }
            if let Ok(existing_text) = fs::read_to_string(&override_path) {
                let fields = desktop_fields(&existing_text);
                if !fields
                    .get("X-SownteeShell-System-Override")
                    .is_some_and(|value| value.eq_ignore_ascii_case("true"))
                {
                    return json!({"ok": false, "message": "A user startup override already exists"});
                }
            }
        }
        let mut override_text = set_desktop_enabled(&text, false);
        override_text.push_str("X-SownteeShell-System-Override=true\n");
        if let Err(error) = fs::create_dir_all(&directory) {
            return json!({"ok": false, "message": error.to_string()});
        }
        return match fs::write(&override_path, override_text) {
            Ok(()) => json!({"ok": true, "message": "System startup disabled for this user"}),
            Err(error) => json!({"ok": false, "message": error.to_string()}),
        };
    }
    update_user_startup_entry(&path, &text, params.enabled)
}

fn update_user_startup_entry(path: &Path, text: &str, enabled: bool) -> Value {
    let updated = set_desktop_enabled(text, enabled);
    match fs::write(path, updated) {
        Ok(()) => json!({"ok": true}),
        Err(error) => json!({"ok": false, "message": error.to_string()}),
    }
}

fn set_desktop_enabled(text: &str, enabled: bool) -> String {
    let mut found_enabled = false;
    let mut found_hidden = false;
    let mut lines = Vec::new();
    for line in text.lines() {
        if line.starts_with("X-GNOME-Autostart-enabled=") {
            lines.push(format!("X-GNOME-Autostart-enabled={enabled}"));
            found_enabled = true;
        } else if line.starts_with("Hidden=") {
            lines.push(format!("Hidden={}", !enabled));
            found_hidden = true;
        } else {
            lines.push(line.to_string());
        }
    }
    if !found_enabled {
        lines.push(format!("X-GNOME-Autostart-enabled={enabled}"));
    }
    if !found_hidden && !enabled && !text.lines().any(|line| line.starts_with("Hidden=")) {
        lines.push("Hidden=true".to_string());
    }
    lines.join("\n") + "\n"
}

async fn unit_state(unit: &str, cancellation: CancellationToken) -> String {
    let Some(systemctl) = command_path("systemctl") else {
        return "inactive".into();
    };
    let Ok(output) = run_bounded(
        &systemctl,
        &["--user", "is-active", unit],
        COMMAND_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await
    else {
        return "inactive".into();
    };
    let state = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if state.is_empty() {
        "inactive".into()
    } else {
        state
    }
}

async fn clear_cache(scope_name: &str) -> Result<()> {
    let scope = cache_scopes()
        .into_iter()
        .find(|scope| scope.scope == scope_name)
        .context("Unknown cache scope")?;
    task::spawn_blocking(move || clear_cache_directory(&scope.path))
        .await
        .context("join diagnostics cache cleanup")??;
    Ok(())
}

fn cache_scopes() -> Vec<CacheScope> {
    let home = env::var_os("HOME").map(PathBuf::from);
    let cache_base = env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| home.map(|path| path.join(".cache")))
        .unwrap_or_else(|| PathBuf::from(".cache"));
    let root = cache_base.join("sownteeshell");
    vec![
        CacheScope {
            scope: "wallpaper-previews",
            label: "Wallpaper previews",
            path: root.join("wallpaper-preview"),
        },
        CacheScope {
            scope: "engine-previews",
            label: "Video previews",
            path: root.join("wallpaper-engine/previews"),
        },
        CacheScope {
            scope: "backdrops",
            label: "Generated backdrops",
            path: root.join("backdrops"),
        },
    ]
}

fn clear_cache_directory(path: &Path) -> Result<()> {
    if let Ok(metadata) = fs::symlink_metadata(path) {
        if metadata.file_type().is_symlink() {
            bail!("Refusing to clear a symbolic-link cache path");
        }
        if metadata.is_dir() {
            fs::remove_dir_all(path)
                .with_context(|| format!("remove cache directory {}", path.display()))?;
        } else {
            bail!("Cache path is not a directory");
        }
    }
    fs::create_dir_all(path)
        .with_context(|| format!("create cache directory {}", path.display()))?;
    Ok(())
}

fn directory_size(directory: &Path) -> u64 {
    let Ok(entries) = fs::read_dir(directory) else {
        return 0;
    };
    entries
        .filter_map(|entry| entry.ok())
        .map(|entry| {
            let Ok(file_type) = entry.file_type() else {
                return 0;
            };
            if file_type.is_symlink() {
                0
            } else if file_type.is_dir() {
                directory_size(&entry.path())
            } else if file_type.is_file() {
                entry.metadata().map(|metadata| metadata.len()).unwrap_or(0)
            } else {
                0
            }
        })
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    #[test]
    fn clears_only_a_directory_target() {
        let root = env::temp_dir().join(format!("diagnostics-test-{}", Uuid::new_v4()));
        let cache = root.join("cache");
        fs::create_dir_all(&cache).expect("create cache");
        fs::write(cache.join("entry"), b"data").expect("write cache entry");
        clear_cache_directory(&cache).expect("clear cache");
        assert!(cache.is_dir());
        assert_eq!(directory_size(&cache), 0);
        fs::remove_dir_all(root).expect("remove test directory");
    }

    #[test]
    fn parses_services_and_hides_shell_units() {
        let output = concat!(
            "Id=example.service\n",
            "Description=Example\n",
            "ActiveState=active\n",
            "SubState=running\n",
            "UnitFileState=enabled\n",
            "MainPID=42\n",
            "MemoryCurrent=4096\n",
            "ActiveEnterTimestamp=now\n\n",
            "Id=sownteeshell-core.service\n",
            "ActiveState=active\n",
            "SubState=running\n",
            "UnitFileState=enabled\n\n"
        );
        let services = parse_service_snapshot(output, true);
        assert_eq!(services.len(), 1);
        assert_eq!(services[0]["name"], "example.service");
        assert_eq!(services[0]["memory"], 4096);
        assert_eq!(services[0]["manageable"], true);
    }

    #[test]
    fn system_snapshot_keeps_disabled_services_manageable() {
        let services = parse_service_snapshot(
            "Id=example.service\nActiveState=inactive\nUnitFileState=disabled\n\nId=sownteeshell-core.service\nActiveState=active\n\n",
            false,
        );
        assert_eq!(services.len(), 1);
        assert_eq!(services[0]["scope"], "system");
        assert_eq!(services[0]["manageable"], true);
        assert_eq!(services[0]["startup"], "disabled");
    }

    #[test]
    fn service_actions_default_to_user_scope() {
        let params =
            serde_json::from_value(json!({"name": "example.service", "action": "start"})).unwrap();
        assert_eq!(
            service_action_arguments(&params).unwrap(),
            ["--user", "--no-pager", "start", "--", "example.service"]
        );
    }

    #[test]
    fn system_service_actions_use_explicit_scope_without_changing_runtime_on_enable() {
        for action in ["start", "stop", "restart", "enable", "disable"] {
            let params = serde_json::from_value(
                json!({"name": "example.service", "action": action, "scope": "system"}),
            )
            .unwrap();
            assert_eq!(
                service_action_arguments(&params).unwrap(),
                ["--system", "--no-pager", action, "--", "example.service"]
            );
        }
    }

    #[test]
    fn rejects_unsafe_or_protected_service_actions() {
        for scope in ["user", "system"] {
            for name in [
                "",
                ".service",
                "--help.service",
                "*.service",
                "example?.service",
                "[ab].service",
                "../example.service",
                "example\n.service",
                "example service.service",
                "sownteeshell-core.service",
                "example.socket",
            ] {
                let params =
                    serde_json::from_value(json!({"name": name, "action": "stop", "scope": scope}))
                        .unwrap();
                assert!(
                    service_action_arguments(&params).is_err(),
                    "must reject {name:?}"
                );
            }
            let params = serde_json::from_value(
                json!({"name": "example.service", "action": "mask", "scope": scope}),
            )
            .unwrap();
            assert!(service_action_arguments(&params).is_err());
        }
        assert!(
            serde_json::from_value::<ServiceActionParams>(
                json!({"name": "example.service", "action": "enable", "scope": "invalid"})
            )
            .is_err()
        );
    }

    #[test]
    fn accepts_instantiated_and_escaped_service_names() {
        for name in ["example@user.service", "example\\x2dworker.service"] {
            let params = serde_json::from_value(
                json!({"name": name, "action": "enable", "scope": "system"}),
            )
            .unwrap();
            assert_eq!(
                service_action_arguments(&params).unwrap().last(),
                Some(&name)
            );
        }
    }
}
