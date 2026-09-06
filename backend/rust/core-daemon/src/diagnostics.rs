use crate::command::{command_path, run_bounded};
use crate::job::JobRegistry;
use anyhow::{Context, Result, bail};
use serde::Deserialize;
use serde_json::{Value, json};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::task;
use tokio_util::sync::CancellationToken;

const COMMAND_OUTPUT_LIMIT: usize = 64 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(4);
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

    let mut services = Vec::new();
    for unit in SERVICES {
        services.push(json!({
            "name": unit,
            "state": unit_state(unit, cancellation.clone()).await,
        }));
    }
    Ok(json!({
        "ok": true,
        "dependencies": dependencies,
        "caches": caches,
        "services": services,
    }))
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
}
