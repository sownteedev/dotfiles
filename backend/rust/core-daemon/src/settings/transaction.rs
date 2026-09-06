use super::SettingsPaths;
use crate::command::{command_path, run_bounded};
use anyhow::{Context, Result, bail};
use serde_json::{Value, json};
use std::collections::BTreeMap;
use std::env;
use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::task;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const COMMAND_OUTPUT_LIMIT: usize = 512 * 1024;
const VALIDATE_TIMEOUT: Duration = Duration::from_secs(20);
const RELOAD_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug)]
pub struct NiriUpdate {
    pub path: PathBuf,
    pub content: String,
}

pub async fn apply_niri_changes(
    paths: &SettingsPaths,
    updates: Vec<NiriUpdate>,
    success_message: &str,
    cancellation: CancellationToken,
) -> Value {
    match apply_niri_changes_inner(paths, updates, cancellation).await {
        Ok(()) => json!({"ok": true, "message": success_message}),
        Err(error) => json!({"ok": false, "message": error.to_string()}),
    }
}

async fn apply_niri_changes_inner(
    paths: &SettingsPaths,
    updates: Vec<NiriUpdate>,
    cancellation: CancellationToken,
) -> Result<()> {
    if updates.is_empty() {
        return Ok(());
    }
    let niri = command_path("niri").context("Niri is not installed")?;
    let paths_for_candidate = paths.clone();
    let prepared = task::spawn_blocking(move || prepare_candidate(&paths_for_candidate, updates))
        .await
        .context("join Niri candidate preparation")??;
    let PreparedCandidate {
        candidate_config,
        temporary: _temporary,
        unique,
    } = prepared;

    let candidate_config_text = candidate_config.to_string_lossy().into_owned();
    let validation = run_bounded(
        &niri,
        &["validate", "-c", &candidate_config_text],
        VALIDATE_TIMEOUT,
        cancellation.clone(),
        COMMAND_OUTPUT_LIMIT,
    )
    .await
    .context("validate candidate Niri configuration")?;
    if !validation.status.success() {
        bail!(
            "Niri rejected the change: {}",
            command_message(&validation.stderr, &validation.stdout)
        );
    }
    if validation.stdout_truncated || validation.stderr_truncated {
        bail!("Niri validation produced too much output");
    }

    let unique_for_read = unique.clone();
    let originals = task::spawn_blocking(move || read_originals(&unique_for_read))
        .await
        .context("join Niri original config read")??;
    let unique_for_publish = unique.clone();
    let originals_for_publish = originals.clone();
    let publish_result =
        task::spawn_blocking(move || publish_updates(&unique_for_publish, &originals_for_publish))
            .await
            .context("join Niri config publish")?;
    let publish_error = match publish_result {
        Ok(()) => reload_niri(&niri, cancellation.clone()).await.err(),
        Err(error) => Some(error),
    };
    if let Some(error) = publish_error {
        let originals_for_rollback = originals.clone();
        let mut rollback_errors =
            task::spawn_blocking(move || rollback_updates(&originals_for_rollback))
                .await
                .context("join Niri config rollback")?;
        if let Err(rollback_error) = reload_niri(&niri, CancellationToken::new()).await {
            rollback_errors.push(format!("reload after rollback: {rollback_error}"));
        }
        if rollback_errors.is_empty() {
            bail!("Could not apply Niri config: {error}");
        }
        bail!(
            "Could not apply Niri config: {error}; rollback errors: {}",
            rollback_errors.join("; ")
        );
    }
    Ok(())
}

struct PreparedCandidate {
    candidate_config: PathBuf,
    temporary: TemporaryDirectory,
    unique: BTreeMap<PathBuf, String>,
}

fn prepare_candidate(paths: &SettingsPaths, updates: Vec<NiriUpdate>) -> Result<PreparedCandidate> {
    let mut unique = BTreeMap::new();
    for update in updates {
        let relative = update.path.strip_prefix(&paths.niri_dir).with_context(|| {
            format!(
                "Refusing to edit a file outside {}",
                paths.niri_dir.display()
            )
        })?;
        if relative.as_os_str().is_empty()
            || relative
                .components()
                .any(|component| matches!(component, std::path::Component::ParentDir))
        {
            bail!("Invalid Niri update path: {}", update.path.display());
        }
        unique.insert(update.path, update.content);
    }

    let temporary = TemporaryDirectory::new("sownteeshell-niri")?;
    let candidate_dir = temporary.path().join("niri");
    copy_tree(&paths.niri_dir, &candidate_dir)?;
    for (path, content) in &unique {
        let relative = path
            .strip_prefix(&paths.niri_dir)
            .expect("Niri update path was validated");
        atomic_write(&candidate_dir.join(relative), content, None)?;
    }
    Ok(PreparedCandidate {
        candidate_config: candidate_dir.join("config.kdl"),
        temporary,
        unique,
    })
}

fn read_originals(unique: &BTreeMap<PathBuf, String>) -> Result<BTreeMap<PathBuf, (String, u32)>> {
    unique
        .keys()
        .map(|path| {
            let content = fs::read_to_string(path)
                .with_context(|| format!("read original {}", path.display()))?;
            let mode = fs::metadata(path)
                .with_context(|| format!("inspect original {}", path.display()))?
                .permissions()
                .mode()
                & 0o777;
            Ok((path.clone(), (content, mode)))
        })
        .collect()
}

fn publish_updates(
    unique: &BTreeMap<PathBuf, String>,
    originals: &BTreeMap<PathBuf, (String, u32)>,
) -> Result<()> {
    for (path, content) in unique {
        let mode = originals.get(path).map(|(_, mode)| *mode).unwrap_or(0o644);
        atomic_write(path, content, Some(mode))?;
    }
    Ok(())
}

fn rollback_updates(originals: &BTreeMap<PathBuf, (String, u32)>) -> Vec<String> {
    let mut errors = Vec::new();
    for (path, (content, mode)) in originals {
        if let Err(error) = atomic_write(path, content, Some(*mode)) {
            errors.push(format!("{}: {error}", path.display()));
        }
    }
    errors
}

async fn reload_niri(niri: &Path, cancellation: CancellationToken) -> Result<()> {
    let output = run_bounded(
        niri,
        &["msg", "action", "load-config-file"],
        RELOAD_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await
    .context("reload Niri configuration")?;
    if output.stdout_truncated || output.stderr_truncated {
        bail!("Niri reload produced too much output");
    }
    if !output.status.success() {
        bail!(
            "{}",
            command_message(&output.stderr, &output.stdout)
                .trim()
                .to_string()
                .or_default("Niri did not reload the config")
        );
    }
    Ok(())
}

fn command_message(stderr: &[u8], stdout: &[u8]) -> String {
    let stderr = String::from_utf8_lossy(stderr).trim().to_string();
    if !stderr.is_empty() {
        return stderr;
    }
    String::from_utf8_lossy(stdout).trim().to_string()
}

trait DefaultString {
    fn or_default(self, fallback: &str) -> String;
}

impl DefaultString for String {
    fn or_default(self, fallback: &str) -> String {
        if self.is_empty() {
            fallback.to_string()
        } else {
            self
        }
    }
}

pub fn atomic_write(path: &Path, content: &str, requested_mode: Option<u32>) -> Result<()> {
    let parent = path
        .parent()
        .with_context(|| format!("{} has no parent directory", path.display()))?;
    fs::create_dir_all(parent).with_context(|| format!("create {}", parent.display()))?;
    let mode = requested_mode
        .or_else(|| {
            fs::metadata(path)
                .ok()
                .map(|metadata| metadata.permissions().mode() & 0o777)
        })
        .unwrap_or(0o644);
    let temporary = parent.join(format!(
        ".{}.{}.tmp",
        path.file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("settings"),
        Uuid::new_v4()
    ));
    let result = (|| -> Result<()> {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(mode)
            .open(&temporary)
            .with_context(|| format!("create {}", temporary.display()))?;
        file.write_all(content.as_bytes())
            .with_context(|| format!("write {}", temporary.display()))?;
        file.sync_all()
            .with_context(|| format!("sync {}", temporary.display()))?;
        fs::rename(&temporary, path).with_context(|| format!("replace {}", path.display()))?;
        sync_directory(parent)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

fn sync_directory(path: &Path) -> Result<()> {
    File::open(path)
        .with_context(|| format!("open directory {}", path.display()))?
        .sync_all()
        .with_context(|| format!("sync directory {}", path.display()))
}

fn copy_tree(source: &Path, destination: &Path) -> Result<()> {
    // Dereference links like Python's shutil.copytree default so validation
    // cannot accidentally read a linked file from the live Niri tree.
    let metadata = fs::metadata(source).with_context(|| format!("inspect {}", source.display()))?;
    if metadata.is_file() {
        fs::copy(source, destination)
            .with_context(|| format!("copy {} to {}", source.display(), destination.display()))?;
        fs::set_permissions(destination, metadata.permissions())?;
        return Ok(());
    }
    if !metadata.is_dir() {
        bail!("Unsupported file type in Niri config: {}", source.display());
    }
    fs::create_dir(destination).with_context(|| format!("create {}", destination.display()))?;
    fs::set_permissions(destination, metadata.permissions())?;
    for entry in fs::read_dir(source).with_context(|| format!("read {}", source.display()))? {
        let entry = entry?;
        copy_tree(&entry.path(), &destination.join(entry.file_name()))?;
    }
    Ok(())
}

struct TemporaryDirectory(PathBuf);

impl TemporaryDirectory {
    fn new(prefix: &str) -> Result<Self> {
        let base = env::var_os("TMPDIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("/tmp"));
        for _ in 0..8 {
            let path = base.join(format!("{prefix}-{}", Uuid::new_v4()));
            match fs::DirBuilder::new().mode(0o700).create(&path) {
                Ok(()) => return Ok(Self(path)),
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => {
                    return Err(error).with_context(|| format!("create {}", path.display()));
                }
            }
        }
        bail!("Could not create a private temporary directory")
    }

    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TemporaryDirectory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
