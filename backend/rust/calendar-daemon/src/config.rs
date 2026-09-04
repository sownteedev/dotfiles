use anyhow::{Context, Result, bail};
use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::time::Duration;

const APP_DIR: &str = "sownteeshell/calendar";

#[derive(Clone)]
pub struct Config {
    pub data_dir: PathBuf,
    pub database_path: PathBuf,
    pub runtime_dir: PathBuf,
    pub socket_path: PathBuf,
    pub sync_interval: Duration,
    pub sync_past_days: i64,
    pub sync_future_days: i64,
    pub google_client_id: Option<String>,
    pub google_client_secret: Option<String>,
    pub microsoft_client_id: Option<String>,
    pub microsoft_tenant: String,
}

impl Config {
    pub fn load() -> Result<Self> {
        let home = env::var_os("HOME").map(PathBuf::from);
        let data_base = env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .or_else(|| home.as_ref().map(|path| path.join(".local/share")))
            .context("HOME or XDG_DATA_HOME is required")?;
        let data_dir = data_base.join(APP_DIR);

        let runtime_dir = env::var_os("XDG_RUNTIME_DIR")
            .map(PathBuf::from)
            .map(|path| path.join(APP_DIR))
            .unwrap_or_else(|| data_dir.join("runtime"));

        create_private_dir(&data_dir)?;
        create_private_dir(&runtime_dir)?;

        let database_path = env::var_os("SOWNTEE_CALENDAR_DB")
            .map(PathBuf::from)
            .unwrap_or_else(|| data_dir.join("calendar.db"));
        let socket_path = env::var_os("SOWNTEE_CALENDAR_SOCKET")
            .map(PathBuf::from)
            .unwrap_or_else(|| runtime_dir.join("calendar.sock"));

        if socket_path.as_os_str().len() > 100 {
            bail!(
                "calendar socket path is too long for a Unix socket: {}",
                socket_path.display()
            );
        }

        let sync_interval_seconds = env_u64("SOWNTEE_CALENDAR_SYNC_INTERVAL_SECONDS", 15 * 60)?;
        if !(30..=24 * 60 * 60).contains(&sync_interval_seconds) {
            bail!("calendar sync interval must be between 30 and 86400 seconds");
        }
        let sync_past_days = env_i64("SOWNTEE_CALENDAR_SYNC_PAST_DAYS", 90)?;
        let sync_future_days = env_i64("SOWNTEE_CALENDAR_SYNC_FUTURE_DAYS", 365)?;
        if !(0..=3650).contains(&sync_past_days) {
            bail!("calendar past sync window must be between 0 and 3650 days");
        }
        if !(1..=3650).contains(&sync_future_days) {
            bail!("calendar future sync window must be between 1 and 3650 days");
        }

        Ok(Self {
            data_dir,
            database_path,
            runtime_dir,
            socket_path,
            sync_interval: Duration::from_secs(sync_interval_seconds),
            sync_past_days,
            sync_future_days,
            google_client_id: non_empty_env("SOWNTEE_CALENDAR_GOOGLE_CLIENT_ID"),
            google_client_secret: non_empty_env("SOWNTEE_CALENDAR_GOOGLE_CLIENT_SECRET"),
            microsoft_client_id: non_empty_env("SOWNTEE_CALENDAR_MICROSOFT_CLIENT_ID"),
            microsoft_tenant: non_empty_env("SOWNTEE_CALENDAR_MICROSOFT_TENANT")
                .unwrap_or_else(|| "common".to_string()),
        })
    }
}

fn create_private_dir(path: &Path) -> Result<()> {
    fs::create_dir_all(path)
        .with_context(|| format!("create private directory {}", path.display()))?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o700))
        .with_context(|| format!("set permissions on {}", path.display()))?;
    Ok(())
}

fn non_empty_env(name: &str) -> Option<String> {
    env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn env_u64(name: &str, default: u64) -> Result<u64> {
    non_empty_env(name)
        .map(|value| {
            value
                .parse()
                .with_context(|| format!("{name} must be an unsigned integer"))
        })
        .transpose()
        .map(|value| value.unwrap_or(default))
}

fn env_i64(name: &str, default: i64) -> Result<i64> {
    non_empty_env(name)
        .map(|value| {
            value
                .parse()
                .with_context(|| format!("{name} must be an integer"))
        })
        .transpose()
        .map(|value| value.unwrap_or(default))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn private_directory_is_namespaced_and_restricted() {
        let root = env::temp_dir().join(format!("calendar-config-test-{}", uuid::Uuid::new_v4()));
        let directory = root.join(APP_DIR);
        create_private_dir(&directory).expect("create private directory");
        assert!(directory.is_dir());
        assert_eq!(
            fs::metadata(&directory)
                .expect("directory metadata")
                .permissions()
                .mode()
                & 0o777,
            0o700
        );
        fs::remove_dir_all(root).ok();
    }
}
