use crate::command::{BoundedOutput, command_path, run_bounded, run_bounded_env};
use crate::job::JobRegistry;
use anyhow::{Context, Result};
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::HashSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::Duration;
use tokio::task;
use tokio_util::sync::CancellationToken;

const COMMAND_OUTPUT_LIMIT: usize = 2 * 1024 * 1024;
const INSPECT_TIMEOUT: Duration = Duration::from_secs(15);
const UNINSTALL_TIMEOUT: Duration = Duration::from_secs(10 * 60);

#[derive(Clone)]
pub struct ApplicationBackend {
    jobs: JobRegistry,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ApplicationParams {
    app_id: String,
}

#[derive(Clone, Serialize)]
struct PackageInfo {
    app_id: String,
    backend: String,
    blockers: Vec<String>,
    desktop_ids: Vec<String>,
    managed: bool,
    message: String,
    package: String,
    removable: bool,
    removal_packages: Vec<String>,
    scope: String,
}

struct RemovalPlan {
    blockers: Vec<String>,
    message: String,
    removable: bool,
    removal_packages: Vec<String>,
}

impl ApplicationBackend {
    pub fn new(jobs: JobRegistry) -> Self {
        Self { jobs }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("application.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let params: ApplicationParams =
            serde_json::from_value(params).context("decode application request")?;
        let app_id = params.app_id.trim().to_string();
        let cancellation = job.cancellation();
        let result = match method {
            "application.inspect" => {
                let info = resolve_package(&app_id, cancellation).await?;
                response(info, true, None)
            }
            "application.uninstall" => uninstall(&app_id, cancellation).await?,
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}

async fn resolve_package(app_id: &str, cancellation: CancellationToken) -> Result<PackageInfo> {
    let mut info = PackageInfo::empty(app_id);
    if app_id.is_empty() {
        return Ok(info);
    }

    let search_id = app_id.to_string();
    let desktop_files = task::spawn_blocking(move || find_desktop_files(&search_id))
        .await
        .context("join desktop file search")?;
    let Some(desktop_file) = desktop_files.first() else {
        return Ok(info);
    };

    let flatpak_id = desktop_flatpak_id(desktop_file);
    if !flatpak_id.is_empty()
        && let Some(scope) = flatpak_scope(&flatpak_id, cancellation.clone()).await?
    {
        info.backend = "flatpak".into();
        info.managed = true;
        info.package = flatpak_id;
        info.removable = true;
        info.scope = scope;
        return Ok(info);
    }

    let mut package = pacman_owner(desktop_file, cancellation.clone()).await?;
    if package.is_empty()
        && let Some(executable) = desktop_executable(desktop_file)
    {
        package = pacman_owner(&executable, cancellation.clone()).await?;
    }
    if package.is_empty() {
        let primary_command = desktop_command(desktop_file)
            .and_then(|command| Path::new(&command).file_name().map(|name| name.to_owned()));
        if let Some(primary_command) = primary_command {
            for packaged_desktop in desktop_files.iter().skip(1) {
                let matches = desktop_command(packaged_desktop)
                    .and_then(|command| Path::new(&command).file_name().map(|name| name.to_owned()))
                    .is_some_and(|command| command == primary_command);
                if !matches {
                    continue;
                }
                package = pacman_owner(packaged_desktop, cancellation.clone()).await?;
                if !package.is_empty() {
                    break;
                }
            }
        }
    }
    if package.is_empty() {
        return Ok(info);
    }

    let plan = pacman_removal_plan(&package, cancellation.clone()).await?;
    info.backend = "pacman".into();
    info.blockers = plan.blockers;
    info.desktop_ids = pacman_desktop_ids(&package, cancellation).await?;
    if info.desktop_ids.is_empty() {
        info.desktop_ids.push(app_id.to_string());
    }
    info.managed = true;
    info.message = plan.message;
    info.package = package;
    info.removable = plan.removable;
    info.removal_packages = plan.removal_packages;
    info.scope = "system".into();
    Ok(info)
}

async fn uninstall(app_id: &str, cancellation: CancellationToken) -> Result<Value> {
    let info = resolve_package(app_id, cancellation.clone()).await?;
    if !info.managed {
        return Ok(response(
            info,
            false,
            Some("Application is not managed by Pacman or Flatpak"),
        ));
    }
    if !info.removable {
        let message = if info.message.is_empty() {
            "Application cannot be uninstalled safely".to_string()
        } else {
            info.message.clone()
        };
        return Ok(response(info, false, Some(&message)));
    }

    let output = if info.backend == "pacman" {
        let Some(pkexec) = command_path("pkexec") else {
            return Ok(response(
                info,
                false,
                Some("Pacman or pkexec is unavailable"),
            ));
        };
        let Some(pacman) = command_path("pacman") else {
            return Ok(response(
                info,
                false,
                Some("Pacman or pkexec is unavailable"),
            ));
        };
        let pacman = pacman.to_string_lossy().into_owned();
        run_bounded(
            &pkexec,
            &[&pacman, "-Rns", "--noconfirm", "--", &info.package],
            UNINSTALL_TIMEOUT,
            cancellation,
            COMMAND_OUTPUT_LIMIT,
        )
        .await?
    } else {
        let Some(flatpak) = command_path("flatpak") else {
            return Ok(response(info, false, Some("Flatpak is unavailable")));
        };
        let scope = format!("--{}", info.scope);
        run_bounded(
            &flatpak,
            &[
                "uninstall",
                &scope,
                "--app",
                "--assumeyes",
                "--noninteractive",
                "--",
                &info.package,
            ],
            UNINSTALL_TIMEOUT,
            cancellation,
            COMMAND_OUTPUT_LIMIT,
        )
        .await?
    };

    if !output.status.success() {
        let message = if info.backend == "pacman" && matches!(output.status.code(), Some(126 | 127))
        {
            "Administrator authorization was cancelled".to_string()
        } else {
            failure_message(&output, "Uninstall was cancelled or failed")
        };
        return Ok(response(info, false, Some(&message)));
    }
    let message = format!("Uninstalled {}", info.package);
    Ok(response(info, true, Some(&message)))
}

impl PackageInfo {
    fn empty(app_id: &str) -> Self {
        Self {
            app_id: app_id.to_string(),
            backend: String::new(),
            blockers: Vec::new(),
            desktop_ids: (!app_id.is_empty())
                .then(|| app_id.to_string())
                .into_iter()
                .collect(),
            managed: false,
            message: String::new(),
            package: String::new(),
            removable: false,
            removal_packages: Vec::new(),
            scope: String::new(),
        }
    }
}

fn response(info: PackageInfo, ok: bool, message: Option<&str>) -> Value {
    let mut value = serde_json::to_value(info).unwrap_or_else(|_| json!({}));
    if let Some(object) = value.as_object_mut() {
        object.insert("ok".into(), Value::Bool(ok));
        if let Some(message) = message {
            object.insert("message".into(), Value::String(message.to_string()));
        }
    }
    value
}

fn data_roots() -> Vec<PathBuf> {
    let home = env::var_os("HOME").map(PathBuf::from);
    let mut roots = vec![
        env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .or_else(|| home.map(|path| path.join(".local/share")))
            .unwrap_or_else(|| PathBuf::from(".local/share")),
    ];
    roots.extend(
        env::var_os("XDG_DATA_DIRS")
            .unwrap_or_else(|| "/usr/local/share:/usr/share".into())
            .to_string_lossy()
            .split(':')
            .filter(|path| !path.is_empty())
            .map(PathBuf::from),
    );
    let mut seen = HashSet::new();
    roots.retain(|root| seen.insert(root.clone()));
    roots
}

fn find_desktop_files(app_id: &str) -> Vec<PathBuf> {
    let mut matches = Vec::new();
    for data_root in data_roots() {
        let applications = data_root.join("applications");
        let direct = applications.join(format!("{app_id}.desktop"));
        if direct.is_file() {
            matches.push(direct);
            continue;
        }
        find_desktop_file_recursive(&applications, &applications, app_id, &mut matches);
    }
    matches
}

fn find_desktop_file_recursive(
    directory: &Path,
    applications: &Path,
    app_id: &str,
    matches: &mut Vec<PathBuf>,
) -> bool {
    let Ok(entries) = fs::read_dir(directory) else {
        return false;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let Ok(file_type) = entry.file_type() else {
            continue;
        };
        if file_type.is_dir() {
            if find_desktop_file_recursive(&path, applications, app_id, matches) {
                return true;
            }
        } else if file_type.is_file()
            && path
                .extension()
                .is_some_and(|extension| extension == "desktop")
            && desktop_id_for(&path, applications).as_deref() == Some(app_id)
        {
            matches.push(path);
            return true;
        }
    }
    false
}

fn desktop_id_for(path: &Path, applications: &Path) -> Option<String> {
    let relative = path.strip_prefix(applications).ok()?.to_string_lossy();
    Some(
        relative
            .strip_suffix(".desktop")
            .unwrap_or(&relative)
            .replace('/', "-"),
    )
}

fn desktop_flatpak_id(path: &Path) -> String {
    read_desktop_value(path, "X-Flatpak").unwrap_or_default()
}

fn desktop_executable(path: &Path) -> Option<PathBuf> {
    let command = desktop_command(path)?;
    let executable = PathBuf::from(command);
    executable.is_absolute().then_some(executable)
}

fn desktop_command(path: &Path) -> Option<String> {
    read_desktop_value(path, "Exec").and_then(|value| first_command_word(&value))
}

fn read_desktop_value(path: &Path, key: &str) -> Option<String> {
    let content = fs::read_to_string(path).ok()?;
    let prefix = format!("{key}=");
    content.lines().find_map(|line| {
        line.strip_prefix(&prefix)
            .map(str::trim)
            .map(str::to_string)
    })
}

fn first_command_word(value: &str) -> Option<String> {
    let mut output = String::new();
    let mut quote = None;
    let mut escaped = false;
    for character in value.chars() {
        if escaped {
            output.push(character);
            escaped = false;
            continue;
        }
        if character == '\\' {
            escaped = true;
            continue;
        }
        if let Some(active_quote) = quote {
            if character == active_quote {
                quote = None;
            } else {
                output.push(character);
            }
            continue;
        }
        if matches!(character, '\'' | '"') {
            quote = Some(character);
        } else if character.is_whitespace() {
            if !output.is_empty() {
                break;
            }
        } else {
            output.push(character);
        }
    }
    (!output.is_empty()).then_some(output)
}

async fn flatpak_scope(app_id: &str, cancellation: CancellationToken) -> Result<Option<String>> {
    let Some(flatpak) = command_path("flatpak") else {
        return Ok(None);
    };
    if !valid_package_name(app_id) {
        return Ok(None);
    }
    for scope in ["user", "system"] {
        let option = format!("--{scope}");
        let output = run_bounded(
            &flatpak,
            &["info", &option, "--", app_id],
            INSPECT_TIMEOUT,
            cancellation.clone(),
            COMMAND_OUTPUT_LIMIT,
        )
        .await?;
        if output.status.success() {
            return Ok(Some(scope.to_string()));
        }
    }
    Ok(None)
}

async fn pacman_owner(path: &Path, cancellation: CancellationToken) -> Result<String> {
    let Some(pacman) = command_path("pacman") else {
        return Ok(String::new());
    };
    let path = path.to_string_lossy();
    let output = run_bounded(
        &pacman,
        &["-Qqo", "--", &path],
        INSPECT_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await?;
    if !output.status.success() {
        return Ok(String::new());
    }
    Ok(first_valid_package(&output.stdout))
}

async fn pacman_desktop_ids(package: &str, cancellation: CancellationToken) -> Result<Vec<String>> {
    let Some(pacman) = command_path("pacman") else {
        return Ok(Vec::new());
    };
    let output = run_bounded(
        &pacman,
        &["-Qlq", package],
        INSPECT_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await?;
    if !output.status.success() {
        return Ok(Vec::new());
    }
    let mut identifiers = Vec::new();
    for line in String::from_utf8_lossy(&output.stdout).lines() {
        let Some(relative) = line
            .split_once("/share/applications/")
            .map(|(_, relative)| relative)
            .and_then(|relative| relative.strip_suffix(".desktop"))
        else {
            continue;
        };
        let identifier = relative.replace('/', "-");
        if !identifier.is_empty() && !identifiers.contains(&identifier) {
            identifiers.push(identifier);
        }
    }
    Ok(identifiers)
}

async fn pacman_removal_plan(
    package: &str,
    cancellation: CancellationToken,
) -> Result<RemovalPlan> {
    let Some(pacman) = command_path("pacman") else {
        return Ok(RemovalPlan {
            blockers: Vec::new(),
            message: "Pacman is unavailable".into(),
            removable: false,
            removal_packages: Vec::new(),
        });
    };
    let output = run_bounded_env(
        &pacman,
        &["-Rs", "--print-format", "%n", "--print", "--", package],
        &[("LC_ALL", "C")],
        INSPECT_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await?;
    if output.status.success() {
        let mut packages = Vec::new();
        for line in String::from_utf8_lossy(&output.stdout).lines() {
            let candidate = line.trim();
            if valid_package_name(candidate) && !packages.iter().any(|item| item == candidate) {
                packages.push(candidate.to_string());
            }
        }
        return Ok(RemovalPlan {
            blockers: Vec::new(),
            message: String::new(),
            removable: true,
            removal_packages: packages,
        });
    }

    let blocker_pattern = Regex::new(r" required by ([A-Za-z0-9@._+:-]+)$")?;
    let mut blockers = Vec::new();
    for line in String::from_utf8_lossy(&output.stdout).lines() {
        let Some(blocker) = blocker_pattern
            .captures(line.trim())
            .and_then(|captures| captures.get(1))
            .map(|value| value.as_str())
        else {
            continue;
        };
        if !blockers.iter().any(|item| item == blocker) {
            blockers.push(blocker.to_string());
        }
    }
    let message = if blockers.is_empty() {
        failure_message(&output, "Application cannot be removed safely")
    } else {
        format!("Required by {}", blockers.join(", "))
    };
    Ok(RemovalPlan {
        blockers,
        message,
        removable: false,
        removal_packages: Vec::new(),
    })
}

fn first_valid_package(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes)
        .lines()
        .map(str::trim)
        .find(|candidate| valid_package_name(candidate))
        .unwrap_or_default()
        .to_string()
}

fn valid_package_name(value: &str) -> bool {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN
        .get_or_init(|| Regex::new(r"^[A-Za-z0-9@._+][A-Za-z0-9@._+:-]*$").unwrap())
        .is_match(value)
}

fn failure_message(output: &BoundedOutput, fallback: &str) -> String {
    let selected = if output.stdout.is_empty() {
        &output.stderr
    } else {
        &output.stdout
    };
    let decoded = String::from_utf8_lossy(selected);
    let message = decoded
        .lines()
        .map(str::trim)
        .rfind(|line| !line.is_empty())
        .unwrap_or(fallback);
    message.chars().take(240).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_quoted_desktop_command() {
        assert_eq!(
            first_command_word("\"/opt/Example App/example\" --flag %U"),
            Some("/opt/Example App/example".into())
        );
    }

    #[test]
    fn accepts_arch_and_flatpak_package_names() {
        assert!(valid_package_name("org.example.App"));
        assert!(valid_package_name("linux-zen-headers"));
        assert!(!valid_package_name("bad package"));
    }

    #[test]
    fn maps_nested_desktop_paths_to_ids() {
        let applications = Path::new("/usr/share/applications");
        assert_eq!(
            desktop_id_for(
                Path::new("/usr/share/applications/vendor/tool.desktop"),
                applications
            ),
            Some("vendor-tool".into())
        );
    }
}
