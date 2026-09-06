use anyhow::{Context, Result, bail};
use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

const APP_DIR: &str = "sownteeshell/core";
const MAX_SOCKET_PATH_BYTES: usize = 100;

#[derive(Clone, Debug)]
pub struct Config {
    pub data_dir: PathBuf,
    pub runtime_dir: PathBuf,
    pub socket_path: PathBuf,
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

        let socket_path = env::var_os("SOWNTEE_CORE_SOCKET")
            .map(PathBuf::from)
            .unwrap_or_else(|| runtime_dir.join("core.sock"));
        if socket_path.as_os_str().len() > MAX_SOCKET_PATH_BYTES {
            bail!(
                "core socket path is too long for a Unix socket: {}",
                socket_path.display()
            );
        }

        Ok(Self {
            data_dir,
            runtime_dir,
            socket_path,
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn private_directory_is_restricted() {
        let root = env::temp_dir().join(format!("core-config-test-{}", uuid::Uuid::new_v4()));
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
