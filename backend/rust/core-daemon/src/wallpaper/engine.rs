use super::util::{command_path, expand_home, failure, modified_millis, write_json_atomic};
use anyhow::{Context, Result};
use filetime::{FileTime, set_file_mtime};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::{Duration, Instant};
use tokio::process::Command;
use tokio::task;
use tokio::time::{sleep, timeout};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const SCAN_CACHE_VERSION: u32 = 2;
const BACKDROP_CACHE_VERSION: &str = "backdrop-v5|resize15-blur3";
const MAX_BACKDROP_CACHE_BYTES: u64 = 96 * 1024 * 1024;
const MAX_BACKDROP_CACHE_FILES: usize = 128;
const PREVIEW_NAMES: &[&str] = &["preview.jpg", "preview.jpeg", "preview.png", "preview.gif"];
const VIDEO_EXTENSIONS: &[&str] = &["mp4", "mkv", "webm", "avi", "mov"];

#[derive(Default, Deserialize)]
struct ScanParams {
    #[serde(default)]
    roots: Vec<String>,
}

#[derive(Default, Deserialize)]
struct ProjectParams {
    path: Option<String>,
}

#[derive(Default, Deserialize)]
struct FrameProbeParams {
    path: Option<String>,
    timeout: Option<f64>,
}

#[derive(Default, Deserialize)]
struct PreviewParams {
    cache_dir: Option<String>,
    source: Option<String>,
    target: Option<String>,
    width: Option<u32>,
}

#[derive(Default, Deserialize)]
struct CachePreviewParams {
    cache_dir: Option<String>,
    source: Option<String>,
    target: Option<String>,
}

#[derive(Default, Deserialize)]
struct BackdropParams {
    cache_dir: Option<String>,
    generate_if_missing: Option<bool>,
    source: Option<String>,
    stable_identity: Option<String>,
}

enum BackdropPreparation {
    Complete(Value),
    Generate {
        source_spec: String,
        target: PathBuf,
        temporary: PathBuf,
    },
}

#[derive(Default, Deserialize, Serialize)]
struct ScanCache {
    version: u32,
    #[serde(default)]
    projects: HashMap<String, Value>,
    #[serde(default)]
    mtimes: HashMap<String, String>,
}

pub async fn scan(params: Value) -> Result<Value> {
    let params: ScanParams = serde_json::from_value(params).unwrap_or_default();
    task::spawn_blocking(move || scan_blocking(&params.roots))
        .await
        .context("join Wallpaper Engine scan")?
}

pub async fn project(params: Value) -> Result<Value> {
    let params: ProjectParams = serde_json::from_value(params).unwrap_or_default();
    let path = expand_home(params.path.unwrap_or_default());
    task::spawn_blocking(move || Ok(scan_project(&path).unwrap_or_else(|| json!({}))))
        .await
        .context("join Wallpaper Engine project scan")?
}

pub async fn frame_probe(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: FrameProbeParams = serde_json::from_value(params).unwrap_or_default();
    let path = expand_home(params.path.unwrap_or_default());
    if path.as_os_str().is_empty() {
        return Ok(failure("invalid_path", "Renderer frame path is missing"));
    }
    let wait_time = Duration::from_secs_f64(params.timeout.unwrap_or(4.0).clamp(0.1, 30.0));
    let deadline = Instant::now() + wait_time;
    let mut previous_signature = None;
    let mut rejected_signature = None;
    let mut stable_reads = 0;

    while Instant::now() < deadline {
        if cancellation.is_cancelled() {
            return Ok(failure("cancelled", "Renderer frame probe was cancelled"));
        }
        match tokio::fs::metadata(&path).await {
            Ok(metadata) => {
                let signature = (metadata.len(), modified_millis(&metadata));
                if metadata.len() > 0 && Some(signature) == previous_signature {
                    stable_reads += 1;
                    if stable_reads >= 2 {
                        if Some(signature) == rejected_signature {
                            sleep(Duration::from_millis(100)).await;
                            continue;
                        }
                        if frame_is_usable(&path, cancellation.clone()).await {
                            return Ok(json!({"ok": true, "ready": true, "path": path}));
                        }
                        rejected_signature = Some(signature);
                        stable_reads = 0;
                    }
                } else {
                    stable_reads = 0;
                }
                previous_signature = Some(signature);
            }
            Err(_) => {
                previous_signature = None;
                stable_reads = 0;
            }
        }
        sleep(Duration::from_millis(100)).await;
    }
    Ok(json!({"ok": true, "ready": false, "path": path}))
}

pub async fn preview(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: PreviewParams = serde_json::from_value(params).unwrap_or_default();
    let source = expand_home(params.source.unwrap_or_default());
    let target = expand_home(params.target.unwrap_or_default());
    let cache_dir = expand_home(params.cache_dir.unwrap_or_default());
    let width = params.width.unwrap_or(960).clamp(128, 4096);
    let source_for_prepare = source.clone();
    let target_for_prepare = target.clone();
    let cache_for_prepare = cache_dir.clone();
    if let Some(result) = task::spawn_blocking(move || {
        prepare_preview(&source_for_prepare, &target_for_prepare, &cache_for_prepare)
    })
    .await
    .context("join Wallpaper Engine preview preparation")??
    {
        return Ok(result);
    }
    let temporary = cache_dir.join(format!(
        ".{}.{}.jpeg",
        target
            .file_stem()
            .and_then(OsStr::to_str)
            .unwrap_or("preview"),
        Uuid::new_v4()
    ));
    let cleanup = TemporaryPath(temporary.clone());
    let Some(ffmpeg) = command_path("ffmpeg") else {
        return Ok(failure("missing_dependency", "FFmpeg is not installed"));
    };
    let mut generated = false;
    for seek in [Some("0.5"), None] {
        if cancellation.is_cancelled() {
            return Ok(failure("cancelled", "Preview generation was cancelled"));
        }
        let _ = tokio::fs::remove_file(&temporary).await;
        let mut command = Command::new("nice");
        command.args(["-n", "10"]);
        command
            .arg(&ffmpeg)
            .args(["-hide_banner", "-loglevel", "error", "-y"]);
        if let Some(seek) = seek {
            command.args(["-ss", seek]);
        }
        command.arg("-i").arg(&source).args([
            "-frames:v",
            "1",
            "-vf",
            &format!(
                "scale='min({width},iw)':'min({width},ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=fast_bilinear,format=yuvj420p"
            ),
            "-q:v",
            "3",
            "-update",
            "1",
        ]);
        command.arg(&temporary);
        match command_output(command, cancellation.clone(), Duration::from_secs(30)).await {
            CommandOutcome::Completed(output) if output.status.success() => {
                if tokio::fs::metadata(&temporary)
                    .await
                    .is_ok_and(|metadata| metadata.is_file() && metadata.len() > 0)
                {
                    generated = true;
                    break;
                }
            }
            CommandOutcome::Cancelled => {
                return Ok(failure("cancelled", "Preview generation was cancelled"));
            }
            _ => {}
        }
    }
    if !generated {
        return Ok(failure(
            "preview_failed",
            "Could not create a static Wallpaper Engine preview",
        ));
    }
    tokio::fs::rename(&temporary, &target).await?;
    cleanup.disarm();
    Ok(json!({"ok": true, "path": target, "existing": false}))
}

fn prepare_preview(source: &Path, target: &Path, cache_dir: &Path) -> Result<Option<Value>> {
    if !source.is_file() {
        return Ok(Some(failure("not_found", "Preview source was not found")));
    }
    if !target_in_cache(target, cache_dir) {
        return Ok(Some(failure(
            "unsafe_path",
            "Refusing to write outside the Wallpaper Engine preview cache",
        )));
    }
    fs::create_dir_all(cache_dir)?;
    if usable_file(target) {
        touch(target);
        return Ok(Some(json!({"ok": true, "path": target, "existing": true})));
    }
    Ok(None)
}

pub async fn cache_preview(params: Value) -> Result<Value> {
    let params: CachePreviewParams = serde_json::from_value(params).unwrap_or_default();
    let source = expand_home(params.source.unwrap_or_default());
    let target = expand_home(params.target.unwrap_or_default());
    let cache_dir = expand_home(params.cache_dir.unwrap_or_default());
    task::spawn_blocking(move || {
        if !source.is_file() {
            return Ok(failure(
                "not_found",
                "Renderer preview source was not found",
            ));
        }
        if !target_in_cache(&target, &cache_dir) {
            return Ok(failure(
                "unsafe_path",
                "Refusing to write outside the Wallpaper Engine preview cache",
            ));
        }
        fs::create_dir_all(&cache_dir)?;
        let temporary = cache_dir.join(format!(".cache-preview-{}.tmp", Uuid::new_v4()));
        let cleanup = TemporaryPath(temporary.clone());
        fs::copy(&source, &temporary)?;
        fs::rename(&temporary, &target)?;
        cleanup.disarm();
        Ok(json!({"ok": true, "path": target}))
    })
    .await
    .context("join renderer preview cache")?
}

pub async fn ensure_backdrop(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: BackdropParams = serde_json::from_value(params).unwrap_or_default();
    let source = expand_home(params.source.unwrap_or_default());
    let cache_dir = expand_home(params.cache_dir.unwrap_or_default());
    let stable_identity = params.stable_identity.unwrap_or_default();
    let generate_if_missing = params.generate_if_missing.unwrap_or(true);
    let source_for_prepare = source.clone();
    let cache_for_prepare = cache_dir.clone();
    let prepared = task::spawn_blocking(move || {
        prepare_backdrop(
            source_for_prepare,
            cache_for_prepare,
            stable_identity,
            generate_if_missing,
        )
    })
    .await
    .context("join backdrop preparation")??;
    let (source_spec, target, temporary) = match prepared {
        BackdropPreparation::Complete(value) => return Ok(value),
        BackdropPreparation::Generate {
            source_spec,
            target,
            temporary,
        } => (source_spec, target, temporary),
    };
    let Some(magick) = command_path("magick") else {
        return Ok(failure(
            "missing_dependency",
            "ImageMagick executable 'magick' was not found",
        ));
    };
    let cleanup = TemporaryPath(temporary.clone());
    let mut command = Command::new(magick);
    command.args([
        source_spec,
        "-resize".into(),
        "15%".into(),
        "-blur".into(),
        "0x3".into(),
    ]);
    command.arg(&temporary);
    let outcome = command_output(command, cancellation, Duration::from_secs(30)).await;
    match outcome {
        CommandOutcome::Cancelled => {
            return Ok(failure("cancelled", "Backdrop generation was cancelled"));
        }
        CommandOutcome::Completed(output)
            if output.status.success()
                && tokio::fs::metadata(&temporary)
                    .await
                    .is_ok_and(|metadata| metadata.is_file() && metadata.len() > 0) => {}
        CommandOutcome::Completed(output) => {
            return Ok(failure(
                "generation_failed",
                String::from_utf8_lossy(&output.stderr).trim().to_string(),
            ));
        }
        CommandOutcome::TimedOut => {
            return Ok(failure(
                "generation_failed",
                "ImageMagick backdrop generation timed out",
            ));
        }
        CommandOutcome::StartFailed(error) => {
            return Ok(failure("generation_failed", error));
        }
    }
    tokio::fs::rename(&temporary, &target).await?;
    cleanup.disarm();
    let cache_for_prune = cache_dir.clone();
    let target_for_prune = target.clone();
    task::spawn_blocking(move || prune_backdrop_cache(&cache_for_prune, &target_for_prune))
        .await
        .context("join backdrop cache pruning")?;
    Ok(json!({"ok": true, "path": target, "existing": false}))
}

fn prepare_backdrop(
    source: PathBuf,
    cache_dir: PathBuf,
    stable_identity: String,
    generate_if_missing: bool,
) -> Result<BackdropPreparation> {
    if !source.is_file() {
        return Ok(BackdropPreparation::Complete(failure(
            "not_found",
            format!("wallpaper source does not exist: {}", source.display()),
        )));
    }
    fs::create_dir_all(&cache_dir)?;
    ensure_backdrop_cache_version(&cache_dir)?;
    remove_legacy_backdrops(&cache_dir);
    let identity = if stable_identity.is_empty() {
        let metadata = source.metadata()?;
        format!(
            "{BACKDROP_CACHE_VERSION}|{}|{}|{}",
            source
                .canonicalize()
                .unwrap_or_else(|_| source.clone())
                .display(),
            metadata.len(),
            modified_millis(&metadata)
        )
    } else {
        format!("{BACKDROP_CACHE_VERSION}|{stable_identity}")
    };
    let key = format!("{:x}", Sha256::digest(identity.as_bytes()));
    let target = cache_dir.join(format!("{key}.png"));
    if usable_file(&target) {
        touch(&target);
        prune_backdrop_cache(&cache_dir, &target);
        return Ok(BackdropPreparation::Complete(
            json!({"ok": true, "path": target, "existing": true}),
        ));
    }
    if !generate_if_missing {
        return Ok(BackdropPreparation::Complete(
            json!({"ok": true, "path": "", "missing": true}),
        ));
    }
    let temporary = cache_dir.join(format!(".{key}.{}.png", Uuid::new_v4()));
    let source_spec = if source
        .extension()
        .and_then(OsStr::to_str)
        .is_some_and(|extension| extension.eq_ignore_ascii_case("gif"))
    {
        format!("{}[0]", source.display())
    } else {
        source.display().to_string()
    };
    Ok(BackdropPreparation::Generate {
        source_spec,
        target,
        temporary,
    })
}

fn scan_blocking(roots: &[String]) -> Result<Value> {
    let cache_path = engine_scan_cache_path();
    let cache = load_scan_cache(&cache_path);
    let mut next_projects = HashMap::new();
    let mut next_mtimes = HashMap::new();
    let mut projects = Vec::new();
    let mut visited = HashSet::new();
    let mut dirty = false;

    for root_text in roots {
        let root = expand_home(root_text);
        let root_key = root
            .canonicalize()
            .unwrap_or_else(|_| root.clone())
            .display()
            .to_string();
        if !visited.insert(root_key) || !root.is_dir() {
            continue;
        }
        let mut entries = fs::read_dir(&root)?
            .filter_map(|entry| entry.ok())
            .map(|entry| entry.path())
            .collect::<Vec<_>>();
        entries.sort_by(|left, right| left.file_name().cmp(&right.file_name()));
        for project_dir in entries {
            let key = project_dir.display().to_string();
            let signature = project_signature(&project_dir);
            next_mtimes.insert(key.clone(), signature.clone());
            if !signature.is_empty()
                && cache.mtimes.get(&key) == Some(&signature)
                && let Some(entry) = cache.projects.get(&key)
            {
                next_projects.insert(key, entry.clone());
                projects.push(entry.clone());
                continue;
            }
            if let Some(entry) = scan_project(&project_dir) {
                next_projects.insert(key, entry.clone());
                projects.push(entry);
                dirty = true;
            }
        }
    }
    if next_projects.keys().collect::<HashSet<_>>() != cache.projects.keys().collect::<HashSet<_>>()
    {
        dirty = true;
    }
    if dirty {
        let next_cache = ScanCache {
            version: SCAN_CACHE_VERSION,
            projects: next_projects,
            mtimes: next_mtimes,
        };
        let _ = write_json_atomic(&cache_path, &next_cache);
    }
    projects.sort_by_key(|item| {
        item.get("title")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_lowercase()
    });
    Ok(Value::Array(projects))
}

fn scan_project(project_dir: &Path) -> Option<Value> {
    let project_file = project_dir.join("project.json");
    if !project_dir.is_dir() || !project_file.is_file() {
        return None;
    }
    let data: Value = serde_json::from_slice(&fs::read(&project_file).ok()?).ok()?;
    let data = data.as_object()?;
    let media_file = data.get("file").and_then(Value::as_str).unwrap_or_default();
    let mut preview = String::new();
    if !media_file.is_empty() {
        let candidate = project_dir.join(media_file);
        if candidate.is_file() && has_extension(&candidate, VIDEO_EXTENSIONS) {
            preview = candidate.display().to_string();
        }
    }
    if preview.is_empty()
        && let Some(configured) = data.get("preview").and_then(Value::as_str)
    {
        let candidate = project_dir.join(configured);
        if candidate.is_file() {
            preview = candidate.display().to_string();
        }
    }
    if preview.is_empty() {
        preview = PREVIEW_NAMES
            .iter()
            .map(|name| project_dir.join(name))
            .find(|candidate| candidate.is_file())
            .map(|candidate| candidate.display().to_string())
            .unwrap_or_default();
    }
    let modified = project_file
        .metadata()
        .map(|metadata| modified_millis(&metadata))
        .unwrap_or(0);
    let id = project_dir
        .file_name()
        .and_then(OsStr::to_str)
        .unwrap_or_default();
    Some(json!({
        "id": id,
        "path": project_dir,
        "title": data.get("title").and_then(Value::as_str).unwrap_or(id),
        "type": data.get("type").and_then(Value::as_str).unwrap_or("unknown").to_lowercase(),
        "file": media_file,
        "preview": preview,
        "modified": modified,
    }))
}

fn project_signature(project_dir: &Path) -> String {
    let Ok(directory) = project_dir.metadata() else {
        return String::new();
    };
    let Ok(project) = project_dir.join("project.json").metadata() else {
        return String::new();
    };
    format!(
        "{}:{}:{}",
        modified_millis(&directory),
        modified_millis(&project),
        project.len()
    )
}

fn load_scan_cache(path: &Path) -> ScanCache {
    let Ok(data) = fs::read(path) else {
        return ScanCache::default();
    };
    let Ok(cache) = serde_json::from_slice::<ScanCache>(&data) else {
        return ScanCache::default();
    };
    if cache.version == SCAN_CACHE_VERSION {
        cache
    } else {
        ScanCache::default()
    }
}

fn engine_scan_cache_path() -> PathBuf {
    let cache_home = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
        .unwrap_or_else(|| PathBuf::from("/tmp"));
    cache_home
        .join("sownteeshell")
        .join("wallpaper-engine")
        .join("scan_cache.json")
}

async fn frame_is_usable(path: &Path, cancellation: CancellationToken) -> bool {
    let Some(magick) = command_path("magick") else {
        return true;
    };
    let mut command = Command::new(magick);
    command
        .arg(path)
        .args([
            "-resize",
            "64x64!",
            "-colorspace",
            "RGB",
            "-format",
            "%[fx:mean] %[fx:standard_deviation]",
            "info:",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
    let CommandOutcome::Completed(output) =
        command_output(command, cancellation, Duration::from_secs(2)).await
    else {
        return false;
    };
    if !output.status.success() {
        return false;
    }
    let values = String::from_utf8_lossy(&output.stdout)
        .split_whitespace()
        .filter_map(|value| value.parse::<f64>().ok())
        .collect::<Vec<_>>();
    values.len() == 2 && (values[0] >= 0.01 || values[1] >= 0.07)
}

fn ensure_backdrop_cache_version(cache_dir: &Path) -> Result<()> {
    let version_file = cache_dir.join(".version");
    let current = fs::read_to_string(&version_file).unwrap_or_default();
    if current.trim() == BACKDROP_CACHE_VERSION {
        return Ok(());
    }
    for path in png_files(cache_dir) {
        let _ = fs::remove_file(path);
    }
    let temporary = cache_dir.join(format!(".version-{}.tmp", Uuid::new_v4()));
    fs::write(&temporary, BACKDROP_CACHE_VERSION)?;
    fs::rename(&temporary, version_file)?;
    Ok(())
}

fn remove_legacy_backdrops(cache_dir: &Path) {
    let Ok(entries) = fs::read_dir(cache_dir) else {
        return;
    };
    for path in entries
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
    {
        let name = path.file_name().and_then(OsStr::to_str).unwrap_or_default();
        if name.ends_with("-main.png") || name.ends_with("-lock.png") {
            let _ = fs::remove_file(path);
        }
    }
}

fn prune_backdrop_cache(cache_dir: &Path, protected: &Path) {
    let mut files = png_files(cache_dir)
        .into_iter()
        .filter_map(|path| {
            let metadata = path.metadata().ok()?;
            Some((modified_millis(&metadata), metadata.len(), path))
        })
        .collect::<Vec<_>>();
    let mut total_bytes = files.iter().map(|(_, size, _)| size).sum::<u64>();
    if files.len() <= MAX_BACKDROP_CACHE_FILES && total_bytes <= MAX_BACKDROP_CACHE_BYTES {
        return;
    }
    files.sort_by_key(|(modified, _, _)| *modified);
    let mut remaining = files.len();
    for (_, size, path) in files {
        if remaining <= MAX_BACKDROP_CACHE_FILES && total_bytes <= MAX_BACKDROP_CACHE_BYTES {
            break;
        }
        if path == protected {
            continue;
        }
        if fs::remove_file(&path).is_ok() {
            remaining = remaining.saturating_sub(1);
            total_bytes = total_bytes.saturating_sub(size);
        }
    }
}

fn png_files(cache_dir: &Path) -> Vec<PathBuf> {
    fs::read_dir(cache_dir)
        .into_iter()
        .flatten()
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| path.is_file() && has_extension(path, &["png"]))
        .collect()
}

fn target_in_cache(target: &Path, cache_dir: &Path) -> bool {
    !target.as_os_str().is_empty()
        && !cache_dir.as_os_str().is_empty()
        && target.parent() == Some(cache_dir)
        && target.file_name().is_some()
}

fn has_extension(path: &Path, extensions: &[&str]) -> bool {
    path.extension()
        .and_then(OsStr::to_str)
        .is_some_and(|extension| {
            extensions
                .iter()
                .any(|expected| extension.eq_ignore_ascii_case(expected))
        })
}

fn usable_file(path: &Path) -> bool {
    path.metadata()
        .is_ok_and(|metadata| metadata.is_file() && metadata.len() > 0)
}

fn touch(path: &Path) {
    let _ = set_file_mtime(path, FileTime::now());
}

async fn command_output(
    mut command: Command,
    cancellation: CancellationToken,
    duration: Duration,
) -> CommandOutcome {
    command.kill_on_drop(true);
    let output = command.output();
    tokio::pin!(output);
    tokio::select! {
        _ = cancellation.cancelled() => CommandOutcome::Cancelled,
        result = timeout(duration, &mut output) => match result {
            Ok(Ok(output)) => CommandOutcome::Completed(output),
            Ok(Err(error)) => CommandOutcome::StartFailed(error.to_string()),
            Err(_) => CommandOutcome::TimedOut,
        }
    }
}

enum CommandOutcome {
    Completed(std::process::Output),
    Cancelled,
    TimedOut,
    StartFailed(String),
}

struct TemporaryPath(PathBuf);

impl TemporaryPath {
    fn disarm(mut self) {
        self.0 = PathBuf::new();
    }
}

impl Drop for TemporaryPath {
    fn drop(&mut self) {
        if !self.0.as_os_str().is_empty() {
            let _ = if self.0.is_dir() {
                fs::remove_dir_all(&self.0)
            } else {
                fs::remove_file(&self.0)
            };
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backdrop_targets_are_scoped_to_cache() {
        assert!(target_in_cache(
            Path::new("/tmp/cache/item.jpg"),
            Path::new("/tmp/cache")
        ));
        assert!(!target_in_cache(
            Path::new("/tmp/outside.jpg"),
            Path::new("/tmp/cache")
        ));
    }

    #[test]
    fn project_signature_changes_with_metadata() {
        let root = std::env::temp_dir().join(format!("engine-test-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).unwrap();
        fs::write(root.join("project.json"), br#"{"title":"Test"}"#).unwrap();
        assert!(!project_signature(&root).is_empty());
        fs::remove_dir_all(root).ok();
    }
}
