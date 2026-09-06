use crate::command::{command_path, run_bounded};
use crate::job::JobRegistry;
use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::{Map, Value, json};
use std::collections::{HashMap, HashSet};
use std::env;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Write};
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::task;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const COMMAND_OUTPUT_LIMIT: usize = 2 * 1024 * 1024;
const DEFAULT_GREETER_DIR: &str = "/var/lib/sownteeshell/greeter";
const LEGACY_GREETER_DIR: &str = "/var/lib/quickshell-greeter";
const KEYBOARD_LAYOUT_OUTPUT_LIMIT: usize = 8 * 1024;
const KEYBOARD_LAYOUT_TIMEOUT: Duration = Duration::from_secs(3);
const SESSION_DIRS: &[&str] = &[
    "/usr/local/share/wayland-sessions",
    "/usr/share/wayland-sessions",
];
const IMAGE_EXTENSIONS: &[&str] = &["avif", "jpeg", "jpg", "png", "webp"];
const VIDEO_EXTENSIONS: &[&str] = &["avi", "m4v", "mkv", "mov", "mp4", "webm"];
const REQUIRED_MD3_COLORS: &[&str] = &[
    "background",
    "error",
    "error_container",
    "on_background",
    "on_error",
    "on_error_container",
    "on_primary",
    "on_primary_container",
    "on_surface",
    "on_surface_variant",
    "outline",
    "outline_variant",
    "primary",
    "primary_container",
    "scrim",
    "shadow",
    "surface",
    "surface_bright",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "surface_container_low",
    "surface_container_lowest",
    "tertiary",
];

#[derive(Clone)]
pub struct GreeterBackend {
    jobs: JobRegistry,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct BackgroundParams {
    #[serde(default)]
    destination: String,
    kind: String,
    source: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ProfileParams {
    #[serde(default)]
    destination: String,
    #[serde(default)]
    source: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SettingsParams {
    #[serde(default = "default_session")]
    default_session: String,
    #[serde(default)]
    destination: String,
    #[serde(default)]
    remember_last_session: bool,
}

#[derive(Debug)]
struct SyncError {
    code: &'static str,
    message: String,
}

struct PreparedBackground {
    destination: PathBuf,
    kind: String,
    source: PathBuf,
    source_text: String,
    temporary_dir: PathBuf,
}

impl SyncError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }

    fn response(self) -> Value {
        json!({
            "ok": false,
            "code": self.code,
            "message": self.message,
        })
    }
}

impl GreeterBackend {
    pub fn new(jobs: JobRegistry) -> Self {
        Self { jobs }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("greeter.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let result = match method {
            "greeter.background.sync" => {
                let params: BackgroundParams =
                    serde_json::from_value(params).context("decode greeter background request")?;
                background_response(params, job.cancellation()).await
            }
            "greeter.profile.sync" => {
                let params: ProfileParams =
                    serde_json::from_value(params).context("decode greeter profile request")?;
                task::spawn_blocking(move || profile_response(params))
                    .await
                    .context("join greeter profile synchronization")?
            }
            "greeter.settings.sync" => {
                let params: SettingsParams =
                    serde_json::from_value(params).context("decode greeter settings request")?;
                task::spawn_blocking(move || settings_response(params))
                    .await
                    .context("join greeter settings synchronization")?
            }
            "greeter.keyboardLayout" => keyboard_layout_with_cancellation(job.cancellation()).await,
            "greeter.sessions.list" => task::spawn_blocking(discover_sessions)
                .await
                .context("join greeter session discovery")?,
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}

pub fn discover_sessions() -> Value {
    let mut sessions = Vec::new();
    let mut seen = HashSet::new();
    for directory in SESSION_DIRS {
        let Ok(entries) = fs::read_dir(directory) else {
            continue;
        };
        let mut paths = entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|path| path.extension().and_then(|value| value.to_str()) == Some("desktop"))
            .collect::<Vec<_>>();
        paths.sort();
        for path in paths {
            let Some(session) = read_session(&path) else {
                continue;
            };
            let Some(session_id) = session.get("id").and_then(Value::as_str) else {
                continue;
            };
            if seen.insert(session_id.to_string()) {
                sessions.push(session);
            }
        }
    }
    sessions.sort_by_key(|session| {
        session
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_lowercase()
    });
    Value::Array(sessions)
}

pub async fn keyboard_layout() -> Value {
    keyboard_layout_with_cancellation(CancellationToken::new()).await
}

async fn keyboard_layout_with_cancellation(cancellation: CancellationToken) -> Value {
    let layout = match environment_keyboard_layout() {
        Some(layout) => layout,
        None => localectl_keyboard_layout(cancellation)
            .await
            .unwrap_or_else(locale_keyboard_layout),
    };
    keyboard_layout_value(layout)
}

fn environment_keyboard_layout() -> Option<String> {
    ["GREETD_KEYBOARD_LAYOUT", "XKB_DEFAULT_LAYOUT"]
        .iter()
        .find_map(|name| {
            env::var(name)
                .ok()
                .and_then(|value| normalize_layout(&value))
        })
}

async fn localectl_keyboard_layout(cancellation: CancellationToken) -> Option<String> {
    let localectl = command_path("localectl")?;
    let output = run_bounded(
        &localectl,
        &["show", "--property=X11Layout", "--value"],
        KEYBOARD_LAYOUT_TIMEOUT,
        cancellation,
        KEYBOARD_LAYOUT_OUTPUT_LIMIT,
    )
    .await
    .ok()?;
    if !output.status.success() || output.stdout_truncated || output.stderr_truncated {
        return None;
    }
    normalize_layout(&String::from_utf8_lossy(&output.stdout))
}

fn locale_keyboard_layout() -> String {
    let locale = ["LC_ALL", "LC_CTYPE", "LANG"]
        .iter()
        .find_map(|name| env::var(name).ok().filter(|value| !value.is_empty()))
        .unwrap_or_default();
    if locale.to_ascii_lowercase().starts_with("vi") {
        "vi".into()
    } else {
        "us".into()
    }
}

fn normalize_layout(value: &str) -> Option<String> {
    let layout = value
        .trim()
        .split(',')
        .next()
        .unwrap_or_default()
        .trim()
        .to_ascii_lowercase();
    (!layout.is_empty() && layout != "n/a").then_some(layout)
}

fn keyboard_layout_value(layout: String) -> Value {
    let layout = normalize_layout(&layout).unwrap_or_else(|| "us".into());
    let label = layout
        .chars()
        .take(5)
        .flat_map(char::to_uppercase)
        .collect::<String>();
    json!({"layout": layout, "label": label})
}

fn read_session(path: &Path) -> Option<Value> {
    let source = fs::read_to_string(path).ok()?;
    let fields = desktop_entry_fields(source.trim_start_matches('\u{feff}'));
    if fields
        .get("Type")
        .map(String::as_str)
        .unwrap_or("Application")
        != "Application"
        || fields.get("Hidden").is_some_and(|value| is_true(value))
        || fields.get("NoDisplay").is_some_and(|value| is_true(value))
    {
        return None;
    }

    let command = parse_session_command(fields.get("Exec").map(String::as_str).unwrap_or(""))?;
    let candidate = fields
        .get("TryExec")
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .unwrap_or(command.first()?.as_str());
    if !executable_available(candidate) {
        return None;
    }

    let session_id = path.file_stem()?.to_str()?;
    let desktop = fields
        .get("DesktopNames")
        .and_then(|value| value.split(';').find(|entry| !entry.is_empty()))
        .unwrap_or(session_id);
    Some(json!({
        "id": session_id,
        "name": fields.get("Name").map(String::as_str).unwrap_or(session_id),
        "comment": fields.get("Comment").map(String::as_str).unwrap_or(""),
        "desktop": desktop,
        "command": command,
    }))
}

fn desktop_entry_fields(source: &str) -> HashMap<String, String> {
    let mut fields = HashMap::new();
    let mut in_desktop_entry = false;
    for raw_line in source.lines() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with(';') {
            continue;
        }
        if line.starts_with('[') && line.ends_with(']') {
            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }
        if !in_desktop_entry {
            continue;
        }
        if let Some((key, value)) = raw_line.split_once('=') {
            fields.insert(key.trim().to_string(), value.trim().to_string());
        }
    }
    fields
}

fn is_true(value: &str) -> bool {
    matches!(
        value.trim().to_ascii_lowercase().as_str(),
        "1" | "true" | "yes"
    )
}

fn executable_available(candidate: &str) -> bool {
    let path = Path::new(candidate);
    if path.is_absolute() {
        return fs::metadata(path).is_ok_and(|metadata| {
            metadata.is_file() && metadata.permissions().mode() & 0o111 != 0
        });
    }
    command_path(candidate).is_some()
}

fn parse_session_command(value: &str) -> Option<Vec<String>> {
    let tokens = shell_split(value)?;
    let command = tokens
        .into_iter()
        .filter_map(|token| strip_desktop_field_codes(&token))
        .collect::<Vec<_>>();
    (!command.is_empty()).then_some(command)
}

fn strip_desktop_field_codes(token: &str) -> Option<String> {
    let mut result = String::with_capacity(token.len());
    let mut characters = token.chars().peekable();
    while let Some(character) = characters.next() {
        if character != '%' {
            result.push(character);
            continue;
        }
        match characters.peek().copied() {
            Some('%') => {
                characters.next();
                result.push('%');
            }
            Some('f' | 'F' | 'u' | 'U' | 'd' | 'D' | 'n' | 'N' | 'i' | 'c' | 'k' | 'v' | 'm') => {
                characters.next();
            }
            _ => result.push('%'),
        }
    }
    (!result.is_empty()).then_some(result)
}

fn shell_split(value: &str) -> Option<Vec<String>> {
    #[derive(Clone, Copy, PartialEq, Eq)]
    enum Quote {
        None,
        Single,
        Double,
    }

    let mut words = Vec::new();
    let mut word = String::new();
    let mut quote = Quote::None;
    let mut started = false;
    let mut characters = value.chars();
    while let Some(character) = characters.next() {
        match quote {
            Quote::None => match character {
                '\'' => {
                    quote = Quote::Single;
                    started = true;
                }
                '"' => {
                    quote = Quote::Double;
                    started = true;
                }
                '\\' => {
                    word.push(characters.next()?);
                    started = true;
                }
                value if value.is_whitespace() => {
                    if started {
                        words.push(std::mem::take(&mut word));
                        started = false;
                    }
                }
                _ => {
                    word.push(character);
                    started = true;
                }
            },
            Quote::Single => {
                if character == '\'' {
                    quote = Quote::None;
                } else {
                    word.push(character);
                }
            }
            Quote::Double => match character {
                '"' => quote = Quote::None,
                '\\' => {
                    word.push(characters.next()?);
                    started = true;
                }
                _ => word.push(character),
            },
        }
    }
    if quote != Quote::None {
        return None;
    }
    if started {
        words.push(word);
    }
    Some(words)
}

fn profile_response(params: ProfileParams) -> Value {
    let destination = destination_path(
        &params.destination,
        "GREETD_PROFILE_DIR",
        default_greeter_dir(),
    );
    let result = if params.source.trim().is_empty() {
        clear_profile(&destination)
    } else {
        sync_profile(&params.source, &destination)
    };
    result.unwrap_or_else(SyncError::response)
}

fn settings_response(params: SettingsParams) -> Value {
    let destination = destination_path(
        &params.destination,
        "GREETD_SETTINGS_DIR",
        default_greeter_dir(),
    );
    write_settings(
        &destination,
        &params.default_session,
        params.remember_last_session,
    )
    .unwrap_or_else(SyncError::response)
}

async fn background_response(params: BackgroundParams, cancellation: CancellationToken) -> Value {
    match sync_background(params, cancellation).await {
        Ok(result) => result,
        Err(error) => error.response(),
    }
}

async fn sync_background(
    params: BackgroundParams,
    cancellation: CancellationToken,
) -> std::result::Result<Value, SyncError> {
    let prepared = task::spawn_blocking(move || prepare_background(params))
        .await
        .map_err(|error| {
            SyncError::new(
                "background_prepare_failed",
                format!("Could not prepare the greetd background: {error}"),
            )
        })??;
    let generated = async {
        let palette_source = render_palette_frame(
            &prepared.source,
            prepared.kind == "engine-video",
            &prepared.temporary_dir,
            cancellation.clone(),
        )
        .await?;
        generate_theme_snapshot(
            &palette_source,
            &prepared.source_text,
            &prepared.temporary_dir,
            cancellation,
        )
        .await
    }
    .await;
    let temporary_dir = prepared.temporary_dir.clone();
    let _ = task::spawn_blocking(move || fs::remove_dir_all(temporary_dir)).await;
    let theme = generated?;
    task::spawn_blocking(move || {
        publish_background(
            &prepared.kind,
            &prepared.source_text,
            &prepared.source,
            &prepared.destination,
            &theme,
        )
    })
    .await
    .map_err(|error| {
        SyncError::new(
            "background_publish_failed",
            format!("Could not publish the greetd background: {error}"),
        )
    })?
}

fn prepare_background(
    params: BackgroundParams,
) -> std::result::Result<PreparedBackground, SyncError> {
    let kind = params.kind.trim().to_string();
    let source_text = params.source.trim().to_string();
    let source = match kind.as_str() {
        "image" => resolve_background_image(&source_text)?,
        "engine-video" => resolve_engine_video(&source_text)?,
        _ => {
            return Err(SyncError::new(
                "invalid_kind",
                "Select an image or Wallpaper Engine video background",
            ));
        }
    };
    let destination = destination_path(
        &params.destination,
        "GREETD_BACKGROUND_DIR",
        default_greeter_dir(),
    );
    ensure_writable_directory(
        &destination,
        "The greetd background directory is not writable",
    )?;

    let temporary_dir = env::temp_dir().join(format!("greetd-palette-{}", Uuid::new_v4()));
    fs::create_dir(&temporary_dir).map_err(background_write_error)?;
    fs::set_permissions(&temporary_dir, fs::Permissions::from_mode(0o700))
        .map_err(background_write_error)?;
    Ok(PreparedBackground {
        destination,
        kind,
        source,
        source_text,
        temporary_dir,
    })
}

fn resolve_background_image(source_text: &str) -> std::result::Result<PathBuf, SyncError> {
    let source = expand_home(Path::new(source_text));
    let initial_metadata = fs::symlink_metadata(&source)
        .map_err(|_| SyncError::new("not_found", "The selected Wallhaven image was not found"))?;
    if initial_metadata.file_type().is_symlink() {
        return Err(SyncError::new(
            "unsupported_image",
            "Symbolic links cannot be used as the greetd background",
        ));
    }
    let source = fs::canonicalize(&source)
        .map_err(|_| SyncError::new("not_found", "The selected Wallhaven image was not found"))?;
    let metadata = fs::symlink_metadata(&source)
        .map_err(|_| SyncError::new("not_found", "The selected Wallhaven image was not found"))?;
    let extension = lower_extension(&source);
    if metadata.file_type().is_symlink()
        || !metadata.is_file()
        || !IMAGE_EXTENSIONS.contains(&extension.as_str())
    {
        return Err(SyncError::new(
            "unsupported_image",
            "The selected file is not a supported image",
        ));
    }
    Ok(source)
}

fn resolve_engine_video(source_text: &str) -> std::result::Result<PathBuf, SyncError> {
    let project_dir = expand_home(Path::new(source_text));
    let initial_metadata = fs::symlink_metadata(&project_dir)
        .map_err(|_| SyncError::new("not_found", "The Wallpaper Engine project was not found"))?;
    if initial_metadata.file_type().is_symlink() {
        return Err(SyncError::new(
            "invalid_project",
            "Symbolic links cannot be used as Wallpaper Engine projects",
        ));
    }
    let project_dir = fs::canonicalize(&project_dir)
        .map_err(|_| SyncError::new("not_found", "The Wallpaper Engine project was not found"))?;
    if !project_dir.is_dir() {
        return Err(SyncError::new(
            "invalid_project",
            "The selected Wallpaper Engine path is not a project",
        ));
    }
    let metadata: Value = fs::read(project_dir.join("project.json"))
        .map_err(|_| {
            SyncError::new(
                "invalid_project",
                "Could not read the Wallpaper Engine project",
            )
        })
        .and_then(|data| {
            serde_json::from_slice(&data).map_err(|_| {
                SyncError::new(
                    "invalid_project",
                    "Could not read the Wallpaper Engine project",
                )
            })
        })?;
    if metadata
        .get("type")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_lowercase()
        != "video"
    {
        return Err(SyncError::new(
            "unsupported_project_type",
            "Only Wallpaper Engine video projects can be used by greetd",
        ));
    }
    let media_name = metadata
        .get("file")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .trim();
    if media_name.is_empty() {
        return Err(SyncError::new(
            "missing_video",
            "The Wallpaper Engine project does not define a video file",
        ));
    }
    let media_path = fs::canonicalize(project_dir.join(media_name)).map_err(|_| {
        SyncError::new(
            "missing_video",
            "The Wallpaper Engine video file was not found",
        )
    })?;
    if media_path == project_dir || !media_path.starts_with(&project_dir) || !media_path.is_file() {
        return Err(SyncError::new(
            "unsafe_video_path",
            "The Wallpaper Engine video path is outside its project",
        ));
    }
    if !VIDEO_EXTENSIONS.contains(&lower_extension(&media_path).as_str()) {
        return Err(SyncError::new(
            "unsupported_video",
            "The Wallpaper Engine project uses an unsupported video format",
        ));
    }
    Ok(media_path)
}

async fn video_sample_time(source: &Path, cancellation: CancellationToken) -> f64 {
    let Some(ffprobe) = command_path("ffprobe") else {
        return 0.5;
    };
    let source = source.to_string_lossy().into_owned();
    let output = run_bounded(
        &ffprobe,
        &[
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            &source,
        ],
        Duration::from_secs(15),
        cancellation,
        64 * 1024,
    )
    .await;
    let Ok(output) = output else {
        return 0.5;
    };
    if !output.status.success() || output.stdout_truncated {
        return 0.5;
    }
    let Ok(duration) = String::from_utf8_lossy(&output.stdout)
        .trim()
        .parse::<f64>()
    else {
        return 0.5;
    };
    if duration <= 0.0 {
        0.5
    } else {
        (duration * 0.1).clamp(0.5, 10.0)
    }
}

async fn render_palette_frame(
    source: &Path,
    video: bool,
    temporary_dir: &Path,
    cancellation: CancellationToken,
) -> std::result::Result<PathBuf, SyncError> {
    let ffmpeg = command_path("ffmpeg").ok_or_else(|| {
        SyncError::new(
            "missing_dependency",
            "ffmpeg is required to generate the greetd color palette",
        )
    })?;
    let frame_path = temporary_dir.join("palette-source.png");
    let sample_time = if video {
        Some(video_sample_time(source, cancellation.clone()).await)
    } else {
        None
    };
    let attempts = if video {
        vec![sample_time, None]
    } else {
        vec![None]
    };
    let source = source.to_string_lossy().into_owned();
    let frame = frame_path.to_string_lossy().into_owned();
    let mut last_message = String::new();
    for sample_time in attempts {
        let _ = fs::remove_file(&frame_path);
        let mut arguments = vec![
            "-hide_banner".to_string(),
            "-loglevel".to_string(),
            "error".to_string(),
            "-y".to_string(),
        ];
        if let Some(sample_time) = sample_time {
            arguments.push("-ss".into());
            arguments.push(format!("{sample_time:.3}"));
        }
        arguments.extend([
            "-i".into(),
            source.clone(),
            "-frames:v".into(),
            "1".into(),
            "-vf".into(),
            "scale=960:-2:force_original_aspect_ratio=decrease".into(),
            frame.clone(),
        ]);
        let references = arguments.iter().map(String::as_str).collect::<Vec<_>>();
        match run_bounded(
            &ffmpeg,
            &references,
            Duration::from_secs(60),
            cancellation.clone(),
            COMMAND_OUTPUT_LIMIT,
        )
        .await
        {
            Ok(output) => {
                last_message = command_message(&output.stdout, &output.stderr);
                if output.status.success()
                    && !output.stdout_truncated
                    && !output.stderr_truncated
                    && fs::metadata(&frame_path)
                        .is_ok_and(|metadata| metadata.is_file() && metadata.len() > 0)
                {
                    return Ok(frame_path);
                }
            }
            Err(error) => last_message = error.to_string(),
        }
    }
    if last_message.is_empty() {
        last_message = "Could not render the selected greetd background".into();
    }
    Err(SyncError::new("palette_frame_failed", last_message))
}

async fn generate_theme_snapshot(
    palette_source: &Path,
    source_text: &str,
    temporary_dir: &Path,
    cancellation: CancellationToken,
) -> std::result::Result<Value, SyncError> {
    let matugen = command_path("matugen").ok_or_else(|| {
        SyncError::new(
            "missing_dependency",
            "Matugen is required to generate the greetd color palette",
        )
    })?;
    let config_path = temporary_dir.join("matugen.toml");
    fs::write(
        &config_path,
        "[config]\nversion_check = false\n\n[templates]\n",
    )
    .map_err(background_write_error)?;
    let config = config_path.to_string_lossy().into_owned();
    let palette = palette_source.to_string_lossy().into_owned();
    let output = run_bounded(
        &matugen,
        &[
            "--config",
            &config,
            "image",
            &palette,
            "--type",
            "scheme-tonal-spot",
            "--mode",
            "dark",
            "--source-color-index",
            "0",
            "--continue-on-error",
            "--json",
            "hex",
            "--dry-run",
            "--quiet",
        ],
        Duration::from_secs(60),
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await
    .map_err(|error| SyncError::new("palette_generation_failed", error.to_string()))?;
    if !output.status.success() || output.stdout_truncated || output.stderr_truncated {
        let message = command_message(&output.stdout, &output.stderr);
        return Err(SyncError::new(
            "palette_generation_failed",
            if message.is_empty() {
                "Matugen could not generate the greetd color palette".into()
            } else {
                message
            },
        ));
    }
    let result: Value = serde_json::from_slice(&output.stdout).map_err(|_| {
        SyncError::new(
            "palette_generation_failed",
            "Matugen returned an invalid greetd color palette",
        )
    })?;
    let colors = result
        .get("colors")
        .and_then(Value::as_object)
        .ok_or_else(|| {
            SyncError::new(
                "palette_generation_failed",
                "Matugen returned an invalid greetd color palette",
            )
        })?;
    let mut md3 = Map::new();
    for (name, variants) in colors {
        if let Some(color) = variants
            .get("default")
            .and_then(|value| value.get("color"))
            .and_then(Value::as_str)
        {
            md3.insert(name.clone(), color.into());
        }
    }
    if REQUIRED_MD3_COLORS
        .iter()
        .any(|name| !md3.contains_key(*name))
    {
        return Err(SyncError::new(
            "palette_generation_failed",
            "Matugen did not return all required greetd colors",
        ));
    }
    Ok(json!({
        "mode": "dark",
        "source": source_text,
        "md3": md3,
    }))
}

fn publish_background(
    kind: &str,
    source_text: &str,
    source: &Path,
    destination_dir: &Path,
    theme: &Value,
) -> std::result::Result<Value, SyncError> {
    let destination = destination_dir.join(format!("background.{}", lower_extension(source)));
    atomic_copy(source, &destination, ".background-").map_err(background_write_error)?;
    let theme_path = destination_dir.join("colors.json");
    atomic_json(&theme_path, theme, ".background-theme-").map_err(background_write_error)?;
    let manifest_path = destination_dir.join("background.json");
    let manifest = json!({
        "version": 1,
        "kind": kind,
        "path": destination,
        "source": source_text,
    });
    atomic_json(&manifest_path, &manifest, ".background-manifest-")
        .map_err(background_write_error)?;
    for entry in fs::read_dir(destination_dir).map_err(background_write_error)? {
        let entry = entry.map_err(background_write_error)?;
        let path = entry.path();
        if path == destination || path == manifest_path {
            continue;
        }
        if !entry
            .file_name()
            .to_string_lossy()
            .starts_with("background.")
        {
            continue;
        }
        let metadata = fs::symlink_metadata(&path).map_err(background_write_error)?;
        if metadata.is_file() && !metadata.file_type().is_symlink() {
            fs::remove_file(path).map_err(background_write_error)?;
        }
    }
    Ok(json!({
        "ok": true,
        "theme_path": theme_path,
        "version": 1,
        "kind": kind,
        "path": destination,
        "source": source_text,
    }))
}

fn lower_extension(path: &Path) -> String {
    path.extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase()
}

fn command_message(stdout: &[u8], stderr: &[u8]) -> String {
    let selected = if stderr.is_empty() { stdout } else { stderr };
    String::from_utf8_lossy(selected).trim().to_string()
}

fn clear_profile(destination: &Path) -> std::result::Result<Value, SyncError> {
    if !destination.exists() {
        return Ok(json!({"ok": true, "path": ""}));
    }
    ensure_writable_directory(destination, "The greetd profile directory is not writable")?;
    for entry in fs::read_dir(destination).map_err(profile_write_error)? {
        let entry = entry.map_err(profile_write_error)?;
        let path = entry.path();
        if !entry.file_name().to_string_lossy().starts_with("profile.") {
            continue;
        }
        let metadata = fs::symlink_metadata(&path).map_err(profile_write_error)?;
        if metadata.is_file() && !metadata.file_type().is_symlink() {
            fs::remove_file(path).map_err(profile_write_error)?;
        }
    }
    Ok(json!({"ok": true, "path": ""}))
}

fn sync_profile(
    source_text: &str,
    destination_dir: &Path,
) -> std::result::Result<Value, SyncError> {
    let source = resolve_image(source_text)?;
    ensure_writable_directory(
        destination_dir,
        "The greetd profile directory is not writable",
    )?;
    let extension = source
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();
    let destination = destination_dir.join(format!("profile.{extension}"));
    atomic_copy(&source, &destination, ".profile-").map_err(profile_write_error)?;

    let manifest_path = destination_dir.join("profile.json");
    let manifest = json!({
        "version": 1,
        "path": destination,
        "source": source_text,
    });
    atomic_json(&manifest_path, &manifest, ".profile-manifest-").map_err(profile_write_error)?;

    for entry in fs::read_dir(destination_dir).map_err(profile_write_error)? {
        let entry = entry.map_err(profile_write_error)?;
        let path = entry.path();
        if path == destination || path == manifest_path {
            continue;
        }
        if !entry.file_name().to_string_lossy().starts_with("profile.") {
            continue;
        }
        let metadata = fs::symlink_metadata(&path).map_err(profile_write_error)?;
        if metadata.is_file() && !metadata.file_type().is_symlink() {
            fs::remove_file(path).map_err(profile_write_error)?;
        }
    }
    Ok(json!({"ok": true, "version": 1, "path": destination, "source": source_text}))
}

fn write_settings(
    destination_dir: &Path,
    default_session: &str,
    remember_last_session: bool,
) -> std::result::Result<Value, SyncError> {
    ensure_writable_directory(
        destination_dir,
        "Greetd storage is not installed. Run the greetd installer first",
    )?;
    let default_session = normalize_session(default_session)?;
    let destination = destination_dir.join("settings.json");
    let payload = json!({
        "defaultSession": default_session,
        "rememberLastSession": remember_last_session,
    });
    atomic_json(&destination, &payload, ".greeter-settings-").map_err(|error| {
        SyncError::new(
            "write_failed",
            format!("Could not update greetd settings: {error}"),
        )
    })?;
    Ok(json!({
        "ok": true,
        "path": destination,
        "defaultSession": default_session,
        "rememberLastSession": remember_last_session,
    }))
}

fn resolve_image(source_text: &str) -> std::result::Result<PathBuf, SyncError> {
    let source = expand_home(Path::new(source_text.trim()));
    let initial_metadata = fs::symlink_metadata(&source)
        .map_err(|_| SyncError::new("not_found", "The selected profile image was not found"))?;
    if initial_metadata.file_type().is_symlink() {
        return Err(unsupported_image());
    }
    let source = fs::canonicalize(&source)
        .map_err(|_| SyncError::new("not_found", "The selected profile image was not found"))?;
    let metadata = fs::symlink_metadata(&source)
        .map_err(|_| SyncError::new("not_found", "The selected profile image was not found"))?;
    let extension = source
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();
    if metadata.file_type().is_symlink()
        || !metadata.is_file()
        || !IMAGE_EXTENSIONS.contains(&extension.as_str())
    {
        return Err(unsupported_image());
    }
    Ok(source)
}

fn unsupported_image() -> SyncError {
    SyncError::new(
        "unsupported_image",
        "Select a PNG, JPEG, WebP, or AVIF image",
    )
}

fn normalize_session(value: &str) -> std::result::Result<String, SyncError> {
    let session = value.trim().chars().take(80).collect::<String>();
    if session.is_empty()
        || !session
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'+' | b'-'))
    {
        return Err(SyncError::new(
            "invalid_session",
            "Select a valid installed desktop session",
        ));
    }
    Ok(session)
}

fn destination_path(value: &str, environment_name: &str, fallback: &str) -> PathBuf {
    let configured = if value.trim().is_empty() {
        env::var_os(environment_name)
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(fallback))
    } else {
        PathBuf::from(value.trim())
    };
    expand_home(&configured)
}

fn default_greeter_dir() -> &'static str {
    if Path::new(DEFAULT_GREETER_DIR).is_dir() || !Path::new(LEGACY_GREETER_DIR).is_dir() {
        DEFAULT_GREETER_DIR
    } else {
        LEGACY_GREETER_DIR
    }
}

fn expand_home(path: &Path) -> PathBuf {
    if path == Path::new("~") {
        return env::var_os("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| path.to_path_buf());
    }
    if let Ok(relative) = path.strip_prefix("~")
        && let Some(home) = env::var_os("HOME")
    {
        return PathBuf::from(home).join(relative);
    }
    path.to_path_buf()
}

fn ensure_writable_directory(
    path: &Path,
    message: &'static str,
) -> std::result::Result<(), SyncError> {
    let metadata = fs::symlink_metadata(path)
        .map_err(|_| SyncError::new("destination_unavailable", message))?;
    if metadata.file_type().is_symlink() || !metadata.is_dir() {
        return Err(SyncError::new("destination_unavailable", message));
    }
    let probe_path = path.join(format!(".sowntee-write-probe-{}", Uuid::new_v4()));
    let probe_result = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&probe_path);
    match probe_result {
        Ok(file) => {
            drop(file);
            fs::remove_file(&probe_path)
                .map_err(|_| SyncError::new("destination_unavailable", message))?;
            Ok(())
        }
        Err(_) => Err(SyncError::new("destination_unavailable", message)),
    }
}

fn atomic_copy(source: &Path, destination: &Path, prefix: &str) -> io::Result<()> {
    let directory = destination.parent().unwrap_or_else(|| Path::new("."));
    let temporary = directory.join(format!("{prefix}{}", Uuid::new_v4()));
    let result = (|| -> io::Result<()> {
        let mut input = File::open(source)?;
        let mut output = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temporary)?;
        io::copy(&mut input, &mut output)?;
        output.flush()?;
        output.sync_all()?;
        fs::set_permissions(&temporary, fs::Permissions::from_mode(0o640))?;
        fs::rename(&temporary, destination)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

fn atomic_json(destination: &Path, payload: &Value, prefix: &str) -> io::Result<()> {
    let directory = destination.parent().unwrap_or_else(|| Path::new("."));
    let temporary = directory.join(format!("{prefix}{}", Uuid::new_v4()));
    let result = (|| -> io::Result<()> {
        let mut data = serde_json::to_vec(payload).map_err(io::Error::other)?;
        data.push(b'\n');
        let mut output = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temporary)?;
        output.write_all(&data)?;
        output.flush()?;
        output.sync_all()?;
        fs::set_permissions(&temporary, fs::Permissions::from_mode(0o640))?;
        fs::rename(&temporary, destination)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

fn profile_write_error(error: io::Error) -> SyncError {
    SyncError::new(
        "write_failed",
        format!("Could not update the profile image: {error}"),
    )
}

fn background_write_error(error: io::Error) -> SyncError {
    SyncError::new(
        "write_failed",
        format!("Could not update the greetd background: {error}"),
    )
}

fn default_session() -> String {
    "niri".into()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;

    fn test_root(name: &str) -> PathBuf {
        let root = env::temp_dir().join(format!("greeter-{name}-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).expect("create test root");
        root
    }

    #[test]
    fn parses_desktop_entry_fields_only_from_the_main_section() {
        let fields = desktop_entry_fields(
            "[Other]\nName=Wrong\n[Desktop Entry]\nType=Application\nName=Niri\nExec=niri --session\n[Desktop Action Extra]\nName=Wrong again\n",
        );
        assert_eq!(fields.get("Type").map(String::as_str), Some("Application"));
        assert_eq!(fields.get("Name").map(String::as_str), Some("Niri"));
        assert_eq!(
            fields.get("Exec").map(String::as_str),
            Some("niri --session")
        );
    }

    #[test]
    fn removes_desktop_field_codes_without_losing_literal_percent_signs() {
        assert_eq!(
            parse_session_command(r#"/usr/bin/env "DESKTOP NAME=Niri" niri %f --label=%%done %U"#),
            Some(vec![
                "/usr/bin/env".into(),
                "DESKTOP NAME=Niri".into(),
                "niri".into(),
                "--label=%done".into(),
            ])
        );
        assert_eq!(parse_session_command("niri 'unterminated"), None);
    }

    #[test]
    fn reads_an_available_wayland_session() {
        let root = test_root("session-entry");
        let executable = root.join("start-session");
        fs::write(&executable, "#!/bin/sh\nexit 0\n").expect("write session executable");
        fs::set_permissions(&executable, fs::Permissions::from_mode(0o755))
            .expect("make session executable");
        let entry = root.join("custom.desktop");
        fs::write(
            &entry,
            format!(
                "[Desktop Entry]\nType=Application\nName=Custom Session\nComment=Test session\nDesktopNames=Custom;Fallback;\nTryExec={}\nExec=\"{}\" --flag %U\n",
                executable.display(),
                executable.display()
            ),
        )
        .expect("write desktop entry");
        let session = read_session(&entry).expect("read session");
        assert_eq!(session["id"], "custom");
        assert_eq!(session["name"], "Custom Session");
        assert_eq!(session["comment"], "Test session");
        assert_eq!(session["desktop"], "Custom");
        assert_eq!(session["command"], json!([executable, "--flag"]));
        fs::remove_dir_all(root).ok();
    }

    #[test]
    fn normalizes_keyboard_layout_values() {
        assert_eq!(normalize_layout(" DE,us \n"), Some("de".into()));
        assert_eq!(normalize_layout("n/a"), None);
        assert_eq!(normalize_layout("  "), None);
    }

    #[test]
    fn formats_keyboard_layout_payload() {
        assert_eq!(
            keyboard_layout_value("de(nodeadkeys)".into()),
            json!({"layout": "de(nodeadkeys)", "label": "DE(NO"})
        );
        assert_eq!(
            keyboard_layout_value(String::new()),
            json!({"layout": "us", "label": "US"})
        );
    }

    #[test]
    fn synchronizes_and_clears_profile_images() {
        let root = test_root("profile");
        let destination = root.join("destination");
        fs::create_dir(&destination).expect("create destination");
        let source = root.join("avatar.png");
        fs::write(&source, b"image-data").expect("write source");
        fs::write(destination.join("profile.jpg"), b"old").expect("write stale profile");

        let result = profile_response(ProfileParams {
            destination: destination.to_string_lossy().into_owned(),
            source: source.to_string_lossy().into_owned(),
        });
        assert_eq!(result["ok"], true);
        assert_eq!(
            fs::read(destination.join("profile.png")).unwrap(),
            b"image-data"
        );
        assert!(!destination.join("profile.jpg").exists());
        assert_eq!(
            fs::metadata(destination.join("profile.png"))
                .unwrap()
                .permissions()
                .mode()
                & 0o777,
            0o640
        );

        let cleared = profile_response(ProfileParams {
            destination: destination.to_string_lossy().into_owned(),
            source: String::new(),
        });
        assert_eq!(cleared["ok"], true);
        assert!(!destination.join("profile.png").exists());
        assert!(!destination.join("profile.json").exists());
        fs::remove_dir_all(root).ok();
    }

    #[test]
    fn rejects_symbolic_link_profile_sources() {
        let root = test_root("symlink");
        let destination = root.join("destination");
        fs::create_dir(&destination).expect("create destination");
        let source = root.join("avatar.png");
        let link = root.join("linked.png");
        fs::write(&source, b"image-data").expect("write source");
        symlink(&source, &link).expect("create source symlink");
        let result = profile_response(ProfileParams {
            destination: destination.to_string_lossy().into_owned(),
            source: link.to_string_lossy().into_owned(),
        });
        assert_eq!(result["ok"], false);
        assert_eq!(result["code"], "unsupported_image");
        fs::remove_dir_all(root).ok();
    }

    #[test]
    fn writes_greeter_settings_atomically() {
        let root = test_root("settings");
        let result = settings_response(SettingsParams {
            default_session: "gnome-wayland".into(),
            destination: root.to_string_lossy().into_owned(),
            remember_last_session: true,
        });
        assert_eq!(result["ok"], true);
        let saved: Value =
            serde_json::from_slice(&fs::read(root.join("settings.json")).unwrap()).unwrap();
        assert_eq!(saved["defaultSession"], "gnome-wayland");
        assert_eq!(saved["rememberLastSession"], true);
        assert_eq!(
            fs::metadata(root.join("settings.json"))
                .unwrap()
                .permissions()
                .mode()
                & 0o777,
            0o640
        );
        fs::remove_dir_all(root).ok();
    }

    #[test]
    fn rejects_invalid_session_names() {
        let root = test_root("invalid-session");
        let result = settings_response(SettingsParams {
            default_session: "niri; reboot".into(),
            destination: root.to_string_lossy().into_owned(),
            remember_last_session: false,
        });
        assert_eq!(result["ok"], false);
        assert_eq!(result["code"], "invalid_session");
        fs::remove_dir_all(root).ok();
    }

    #[test]
    fn resolves_wallpaper_engine_video_projects() {
        let root = test_root("engine-video");
        let project = root.join("project");
        fs::create_dir(&project).expect("create project");
        let video = project.join("wallpaper.mp4");
        fs::write(&video, b"video").expect("write video");
        fs::write(
            project.join("project.json"),
            br#"{"type":"Video","file":"wallpaper.mp4"}"#,
        )
        .expect("write project metadata");
        assert_eq!(
            resolve_engine_video(&project.to_string_lossy()).unwrap(),
            fs::canonicalize(video).unwrap()
        );
        fs::remove_dir_all(root).ok();
    }

    #[test]
    fn publishes_background_files_atomically() {
        let root = test_root("background");
        let destination = root.join("destination");
        fs::create_dir(&destination).expect("create destination");
        let source = root.join("wallpaper.jpg");
        fs::write(&source, b"wallpaper").expect("write wallpaper");
        fs::write(destination.join("background.png"), b"old").expect("write stale background");
        let theme = json!({"mode": "dark", "source": source, "md3": {"primary": "#ffffff"}});
        let result = publish_background(
            "image",
            &source.to_string_lossy(),
            &source,
            &destination,
            &theme,
        )
        .unwrap();
        assert_eq!(result["ok"], true);
        assert_eq!(
            fs::read(destination.join("background.jpg")).unwrap(),
            b"wallpaper"
        );
        assert!(!destination.join("background.png").exists());
        assert!(destination.join("background.json").is_file());
        assert!(destination.join("colors.json").is_file());
        for path in [
            destination.join("background.jpg"),
            destination.join("background.json"),
            destination.join("colors.json"),
        ] {
            assert_eq!(
                fs::metadata(path).unwrap().permissions().mode() & 0o777,
                0o640
            );
        }
        fs::remove_dir_all(root).ok();
    }
}
