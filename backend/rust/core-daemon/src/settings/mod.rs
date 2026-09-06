mod apply;
mod parser;
mod snapshot;
mod transaction;

use crate::job::JobRegistry;
use anyhow::{Context, Result, bail};
use serde_json::Value;
use std::env;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::task;

#[derive(Clone)]
pub struct SettingsBackend {
    jobs: JobRegistry,
    transaction: Arc<Mutex<()>>,
}

impl SettingsBackend {
    pub fn new(jobs: JobRegistry) -> Self {
        Self {
            jobs,
            transaction: Arc::new(Mutex::new(())),
        }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("settings.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let paths = match SettingsPaths::from_params(&params) {
            Ok(paths) => paths,
            Err(error) => {
                return Ok(Some(serde_json::json!({
                    "ok": false,
                    "message": error.to_string(),
                })));
            }
        };
        let _guard = self.transaction.lock().await;
        let result = match method {
            "settings.snapshot" => task::spawn_blocking(move || snapshot::build(&paths))
                .await
                .context("join settings snapshot")??,
            "settings.layout.apply" => apply::layout(&paths, &params, job.cancellation()).await,
            "settings.keybind.apply" => apply::keybind(&paths, &params, job.cancellation()).await,
            "settings.input.apply" => apply::input(&paths, &params, job.cancellation()).await,
            "settings.input.enabled" => {
                apply::input_enabled(&paths, &params, job.cancellation()).await
            }
            "settings.input.entryEnabled" => {
                apply::input_entry_enabled(&paths, &params, job.cancellation()).await
            }
            "settings.animations.apply" => {
                apply::animation_global(&paths, &params, job.cancellation()).await
            }
            "settings.animation.apply" => {
                apply::animation_entry(&paths, &params, job.cancellation()).await
            }
            "settings.behavior.apply" => apply::behavior(&paths, &params, job.cancellation()).await,
            "settings.niriFile.apply" => {
                apply::niri_file(&paths, &params, job.cancellation()).await
            }
            "settings.quickshell.apply" => {
                apply::quickshell(&paths, &params, job.cancellation()).await
            }
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}

#[derive(Clone, Debug)]
pub struct SettingsPaths {
    pub sownteeshell_dir: PathBuf,
    pub niri_dir: PathBuf,
    pub include_dir: PathBuf,
    pub config_qml: PathBuf,
    pub runtime_settings: PathBuf,
}

impl SettingsPaths {
    pub fn from_params(params: &Value) -> Result<Self> {
        let sownteeshell_dir = params
            .get("quickshellDir")
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
            .context("quickshellDir is required")?;
        if !sownteeshell_dir.is_absolute() {
            bail!("quickshellDir must be an absolute path");
        }

        let dotfiles_dir = sownteeshell_dir
            .parent()
            .context("quickshellDir has no parent directory")?;
        let niri_dir = dotfiles_dir.join("dotf/.config/niri");
        let include_dir = niri_dir.join("include");
        let config_qml = sownteeshell_dir.join("Config.qml");
        require_directory(&sownteeshell_dir, "SownteeShell directory")?;
        require_directory(&niri_dir, "Niri directory")?;
        require_directory(&include_dir, "Niri include directory")?;
        require_file(&config_qml, "Quickshell Config.qml")?;

        let cache_home = env::var_os("XDG_CACHE_HOME")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
            .context("XDG_CACHE_HOME and HOME are both unavailable")?;

        Ok(Self {
            sownteeshell_dir,
            niri_dir,
            include_dir,
            config_qml,
            runtime_settings: cache_home.join("sownteeshell/settings.json"),
        })
    }
}

fn require_directory(path: &Path, label: &str) -> Result<()> {
    if !path.is_dir() {
        bail!("{label} does not exist: {}", path.display());
    }
    Ok(())
}

fn require_file(path: &Path, label: &str) -> Result<()> {
    if !path.is_file() {
        bail!("{label} does not exist: {}", path.display());
    }
    Ok(())
}
