use super::util::{
    command_path, copy_directory, directory_size, expand_home, failure, modified_millis,
    modified_seconds, write_json_atomic,
};
use anyhow::{Context, Result};
use memmap2::Mmap;
use nix::sys::signal::{Signal, killpg};
use nix::unistd::Pid;
use regex::{Regex, bytes::Regex as BytesRegex};
use reqwest::{Client, StatusCode};
use serde::Deserialize;
use serde_json::{Map, Value, json};
use std::collections::{HashMap, HashSet, VecDeque};
use std::ffi::{OsStr, OsString};
use std::fs;
use std::os::unix::fs::{PermissionsExt, symlink};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command as StdCommand, Stdio};
use std::sync::LazyLock;
use std::time::Duration;
use tokio::io::AsyncReadExt;
use tokio::process::{Child, Command};
use tokio::task;
use tokio::time::{sleep, timeout};
use tokio_util::sync::CancellationToken;

const APP_ID: &str = "431960";
const API_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_API_RESPONSE_BYTES: usize = 8 * 1024 * 1024;
const MAX_STEAMCMD_PIPE_BYTES: usize = 512 * 1024;
const QUERY_ENDPOINT: &str = "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/";
const USER_AGENT: &str = "SownteeShell-Wallpaper-Workshop/1.0";
const UNSUPPORTED_WORKSHOP_TYPES: &[&str] = &["application", "web"];
const NSFW_CONTENT_DESCRIPTOR_IDS: &[u64] = &[1, 3, 4];

static RESOLUTION_PATTERN: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:^|[^0-9])(\d{3,5})\s*[x×]\s*(\d{3,5})(?:[^0-9]|$)").unwrap()
});
static SCENE_HEIGHT_WIDTH_PATTERN: LazyLock<BytesRegex> = LazyLock::new(|| {
    BytesRegex::new(r#""height"\s*:\s*(\d{2,5})\s*,\s*"width"\s*:\s*(\d{2,5})"#).unwrap()
});
static SCENE_WIDTH_HEIGHT_PATTERN: LazyLock<BytesRegex> = LazyLock::new(|| {
    BytesRegex::new(r#""width"\s*:\s*(\d{2,5})\s*,\s*"height"\s*:\s*(\d{2,5})"#).unwrap()
});
static SUBSCRIPTION_ENTRY_PATTERN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)"(\d+)"\s*\{([^{}]*)\}"#).unwrap());
static SUBSCRIBED_BY_PATTERN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#""subscribedby"\s*"[^"]+""#).unwrap());
static LOGIN_FAILURE_PATTERN: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(login failure|invalid password|two-factor|steam guard|cached credentials)")
        .unwrap()
});

#[derive(Default, Deserialize)]
struct SearchParams {
    api_key: Option<String>,
    #[serde(default)]
    excluded_tags: Vec<String>,
    legacy_workshop_root: Option<String>,
    match_all_tags: Option<bool>,
    page: Option<u64>,
    query: Option<String>,
    #[serde(default)]
    required_tags: Vec<String>,
    sort: Option<String>,
    steam_root: Option<String>,
    workshop_root: Option<String>,
}

#[derive(Default, Deserialize)]
struct ListParams {
    legacy_workshop_root: Option<String>,
    steam_root: Option<String>,
    workshop_root: Option<String>,
}

#[derive(Default, Deserialize)]
struct SubscriptionsParams {
    steam_root: Option<String>,
}

#[derive(Default, Deserialize)]
struct DownloadParams {
    id: Option<String>,
    steam_root: Option<String>,
    username: Option<String>,
    workshop_root: Option<String>,
}

#[derive(Default, Deserialize)]
struct RemoveParams {
    current_path: Option<String>,
    id: Option<String>,
    legacy_workshop_root: Option<String>,
    path: Option<String>,
    workshop_root: Option<String>,
}

#[derive(Default, Deserialize)]
struct PruneParams {
    max_bytes: Option<u64>,
    max_files: Option<usize>,
    path: Option<String>,
}

#[derive(Default)]
struct SizeCache {
    entries: HashMap<String, Value>,
    dirty: bool,
}

pub async fn search(
    client: &Client,
    params: Value,
    cancellation: CancellationToken,
) -> Result<Value> {
    let params: SearchParams = serde_json::from_value(params).unwrap_or_default();
    let api_key = trimmed(params.api_key);
    if api_key.is_empty() {
        return Ok(failure("missing_api_key", "Steam Web API key is missing"));
    }
    let query_type = match params.sort.as_deref().unwrap_or("trending") {
        "popular" => 0,
        "recent" => 1,
        _ => 3,
    };
    let mut excluded_tags = normalized_tag_list(params.excluded_tags);
    let excluded_names = excluded_tags
        .iter()
        .map(|tag| tag.to_lowercase())
        .collect::<HashSet<_>>();
    for unsupported in ["Application", "Web"] {
        if !excluded_names.contains(&unsupported.to_lowercase()) {
            excluded_tags.push(unsupported.to_string());
        }
    }
    let query_parameters = json!({
        "query_type": query_type,
        "page": params.page.unwrap_or(1).clamp(1, 10_000),
        "numperpage": 30,
        "appid": APP_ID,
        "search_text": trimmed(params.query),
        "return_metadata": true,
        "return_tags": true,
        "return_previews": true,
        "return_vote_data": true,
        "return_short_description": true,
        "strip_description_bbcode": true,
        "requiredtags": normalized_tag_list(params.required_tags),
        "match_all_tags": params.match_all_tags.unwrap_or(true),
        "excludedtags": excluded_tags,
    });
    let input_json = serde_json::to_string(&query_parameters)?;
    let request = client
        .get(QUERY_ENDPOINT)
        .header(reqwest::header::USER_AGENT, USER_AGENT)
        .timeout(API_TIMEOUT)
        .query(&[
            ("key", api_key.as_str()),
            ("input_json", input_json.as_str()),
        ]);
    let response = tokio::select! {
        _ = cancellation.cancelled() => return Ok(failure("cancelled", "Steam Workshop request was cancelled")),
        response = request.send() => response,
    };
    let mut response = match response {
        Ok(response) => response,
        Err(_) => {
            return Ok(failure("network_error", "Could not reach Steam Workshop"));
        }
    };
    if !response.status().is_success() {
        return Ok(
            if matches!(
                response.status(),
                StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN
            ) {
                failure("authentication_required", "Steam rejected the Web API key")
            } else {
                failure(
                    "http_error",
                    format!(
                        "Steam Workshop request failed ({})",
                        response.status().as_u16()
                    ),
                )
            },
        );
    }
    if response
        .content_length()
        .is_some_and(|length| length > MAX_API_RESPONSE_BYTES as u64)
    {
        return Ok(failure(
            "response_too_large",
            "Steam Workshop response exceeded 8 MiB",
        ));
    }
    let mut bytes = Vec::with_capacity(
        response
            .content_length()
            .unwrap_or_default()
            .min(MAX_API_RESPONSE_BYTES as u64) as usize,
    );
    loop {
        let chunk = tokio::select! {
            _ = cancellation.cancelled() => return Ok(failure("cancelled", "Steam Workshop request was cancelled")),
            chunk = response.chunk() => chunk,
        };
        match chunk {
            Ok(Some(chunk)) => {
                if bytes.len().saturating_add(chunk.len()) > MAX_API_RESPONSE_BYTES {
                    return Ok(failure(
                        "response_too_large",
                        "Steam Workshop response exceeded 8 MiB",
                    ));
                }
                bytes.extend_from_slice(&chunk);
            }
            Ok(None) => break,
            Err(_) => {
                return Ok(failure(
                    "invalid_response",
                    "Steam returned unreadable search data",
                ));
            }
        }
    }
    let Ok(payload) = serde_json::from_slice::<Value>(&bytes) else {
        return Ok(failure(
            "invalid_response",
            "Steam returned unreadable search data",
        ));
    };
    let roots = vec![
        trimmed(params.workshop_root),
        trimmed(params.legacy_workshop_root),
    ];
    let steam_root = steam_root(params.steam_root);
    task::spawn_blocking(move || {
        let subscribed = subscribed_ids(&steam_root);
        let mut cache = SizeCache::load();
        let result = normalize_search_response(&payload, &roots, &subscribed, &mut cache);
        cache.save();
        result
    })
    .await
    .context("join Steam Workshop response normalizer")
}

pub async fn list_installed(params: Value) -> Result<Value> {
    let params: ListParams = serde_json::from_value(params).unwrap_or_default();
    task::spawn_blocking(move || list_installed_blocking(params))
        .await
        .context("join Steam Workshop installed scan")?
}

pub async fn subscriptions(params: Value) -> Result<Value> {
    let params: SubscriptionsParams = serde_json::from_value(params).unwrap_or_default();
    task::spawn_blocking(move || {
        let mut ids = subscribed_ids(&steam_root(params.steam_root))
            .into_iter()
            .collect::<Vec<_>>();
        ids.sort_by_key(|id| id.parse::<u64>().unwrap_or_default());
        json!({"ok": true, "ids": ids})
    })
    .await
    .context("join Steam Workshop subscriptions scan")
}

pub async fn download(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: DownloadParams = serde_json::from_value(params).unwrap_or_default();
    let published_file_id = trimmed(params.id);
    let username = trimmed(params.username);
    if !numeric_id(&published_file_id) {
        return Ok(failure("invalid_id", "Invalid Workshop item ID"));
    }
    if username.is_empty() {
        return Ok(failure("missing_username", "Steam username is missing"));
    }
    let steam_root = steam_root(params.steam_root);
    let workshop_root_text = trimmed(params.workshop_root);
    if workshop_root_text.is_empty() {
        return Ok(failure(
            "missing_workshop_root",
            "Wallpaper Engine Workshop folder is missing",
        ));
    }
    let workshop_root = expand_home(workshop_root_text);
    let target = workshop_root.join(&published_file_id);
    let staging = workshop_root.join(format!(".{published_file_id}.download"));
    let target_for_prepare = target.clone();
    let staging_for_prepare = staging.clone();
    let prepared = task::spawn_blocking(move || {
        let cleanup_paths = [target_for_prepare, staging_for_prepare]
            .into_iter()
            .filter(|path| !path.exists())
            .collect::<Vec<_>>();
        let (launcher, environment) = prepare_steamcmd_session()?;
        Ok::<_, anyhow::Error>((cleanup_paths, launcher, environment))
    })
    .await
    .context("join SteamCMD session preparation")?;
    let (cleanup_paths, launcher, environment) = match prepared {
        Ok(prepared) => prepared,
        Err(_) => {
            return Ok(failure(
                "steamcmd_unavailable",
                "Could not prepare the SteamCMD login session",
            ));
        }
    };
    let cleanup = DownloadCleanup(cleanup_paths);
    let mut command = Command::new(launcher);
    command
        .args(["+force_install_dir"])
        .arg(&steam_root)
        .args([
            "+login",
            &username,
            "+workshop_download_item",
            APP_ID,
            &published_file_id,
            "validate",
            "+quit",
        ])
        .env_clear()
        .envs(environment)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);
    command.as_std_mut().process_group(0);
    let output = match run_steamcmd(command, cancellation).await {
        SteamCommandOutcome::Completed { success, output } => {
            if !success || output.contains("ERROR! Download item") {
                if LOGIN_FAILURE_PATTERN.is_match(&output) {
                    return Ok(failure(
                        "steamcmd_login_required",
                        "SteamCMD login required for SownteeShell; sign in once from a terminal",
                    ));
                }
                return Ok(failure(
                    "download_failed",
                    "SteamCMD could not download this Workshop item",
                ));
            }
            output
        }
        SteamCommandOutcome::Cancelled => {
            return Ok(failure("cancelled", "Workshop download was cancelled"));
        }
        SteamCommandOutcome::TimedOut => {
            return Ok(failure("download_failed", "SteamCMD download timed out"));
        }
        SteamCommandOutcome::StartFailed => {
            return Ok(failure("download_failed", "Could not start SteamCMD"));
        }
    };
    drop(output);

    let id_for_source = published_file_id.clone();
    let steam_for_source = steam_root.clone();
    let workshop_for_source = workshop_root.clone();
    let source = task::spawn_blocking(move || {
        find_downloaded_project(&id_for_source, &steam_for_source, &workshop_for_source)
    })
    .await
    .context("join Workshop download discovery")?;
    let Some(source) = source else {
        return Ok(failure(
            "download_failed",
            "SteamCMD finished but the wallpaper files were not found",
        ));
    };
    let target_for_install = target.clone();
    let id_for_install = published_file_id.clone();
    let installed = task::spawn_blocking(move || {
        finish_download(&source, &target_for_install, &id_for_install)
    })
    .await
    .context("join Workshop install")?;
    let result = match installed {
        Ok(result) => result,
        Err(_) => {
            return Ok(failure(
                "install_failed",
                "Could not install the downloaded wallpaper",
            ));
        }
    };
    cleanup.disarm();
    Ok(result)
}

fn finish_download(source: &Path, target: &Path, published_file_id: &str) -> Result<Value> {
    let target = install_download(source, target)?;
    let project_file = target.join("project.json");
    let metadata: Value = fs::read(&project_file)
        .ok()
        .and_then(|value| serde_json::from_slice(&value).ok())
        .unwrap_or_else(|| json!({}));
    let title = metadata
        .get("title")
        .and_then(Value::as_str)
        .unwrap_or(published_file_id);
    let file_metadata = project_file.metadata()?;
    let mut cache = SizeCache::load();
    let file_size = cache.directory_size(&target);
    cache.save();
    Ok(json!({
        "ok": true,
        "id": published_file_id,
        "path": target,
        "title": title,
        "file_size": file_size,
        "modified": modified_millis(&file_metadata),
    }))
}

pub async fn remove(params: Value) -> Result<Value> {
    let params: RemoveParams = serde_json::from_value(params).unwrap_or_default();
    task::spawn_blocking(move || remove_blocking(params))
        .await
        .context("join Workshop remove")?
}

pub async fn prune_preview_cache(params: Value) -> Result<Value> {
    let params: PruneParams = serde_json::from_value(params).unwrap_or_default();
    task::spawn_blocking(move || Ok(prune_preview_cache_blocking(params)))
        .await
        .context("join preview cache prune")?
}

pub fn login(username: &str) -> Result<i32> {
    let username = username.trim();
    if username.is_empty() {
        anyhow::bail!("Steam username is missing");
    }
    let (launcher, environment) = prepare_steamcmd_session()
        .context("Could not prepare the dedicated SteamCMD login session")?;
    let status = StdCommand::new(launcher)
        .args(["+login", username, "+quit"])
        .env_clear()
        .envs(environment)
        .status()
        .context("Could not start the dedicated SteamCMD login session")?;
    Ok(status.code().unwrap_or(1))
}

fn normalize_search_response(
    payload: &Value,
    roots: &[String],
    subscribed: &HashSet<String>,
    cache: &mut SizeCache,
) -> Value {
    let Some(response) = payload.get("response").and_then(Value::as_object) else {
        return failure("invalid_response", "Steam returned an invalid response");
    };
    let mut items = Vec::new();
    for raw_item in response
        .get("publishedfiledetails")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_object)
    {
        if integer(raw_item.get("result"), 1) != 1 {
            continue;
        }
        let published_file_id = text(raw_item.get("publishedfileid"));
        if !numeric_id(&published_file_id) {
            continue;
        }
        let tags = raw_item
            .get("tags")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(Value::as_object)
            .filter_map(|tag| tag.get("tag").and_then(Value::as_str))
            .map(str::to_string)
            .collect::<Vec<_>>();
        let item_type = wallpaper_type(&tags);
        if UNSUPPORTED_WORKSHOP_TYPES.contains(&item_type.as_str()) {
            continue;
        }
        let local_path = installed_path(&published_file_id, roots);
        let preview = text(raw_item.get("preview_url"));
        let preview = if preview.is_empty() {
            raw_item
                .get("previews")
                .and_then(Value::as_array)
                .and_then(|previews| previews.first())
                .and_then(Value::as_object)
                .and_then(|preview| preview.get("url").or_else(|| preview.get("preview_url")))
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string()
        } else {
            preview
        };
        let remote_file_size = integer(raw_item.get("file_size"), 0);
        let (path, file_size, modified) = if let Some(path) = local_path {
            let modified = path
                .join("project.json")
                .metadata()
                .map(|metadata| modified_millis(&metadata))
                .unwrap_or(0);
            let size = cache.directory_size(&path);
            (path.display().to_string(), size, modified)
        } else {
            (String::new(), remote_file_size, 0)
        };
        items.push(json!({
            "id": published_file_id,
            "title": text(raw_item.get("title")).or_id(raw_item.get("publishedfileid")),
            "preview": preview,
            "type": item_type,
            "resolution": wallpaper_resolution(raw_item, &tags),
            "tags": tags,
            "subscriptions": integer(raw_item.get("subscriptions"), 0),
            "updated": integer(raw_item.get("time_updated"), 0),
            "supported": true,
            "downloaded": !path.is_empty(),
            "subscribed": subscribed.contains(&published_file_id),
            "path": path,
            "file_size": file_size,
            "modified": modified,
            "nsfw": is_nsfw_item(raw_item, &tags),
        }));
    }
    let item_count = items.len() as u64;
    json!({
        "ok": true,
        "items": items,
        "total": integer(response.get("total"), item_count),
    })
}

fn list_installed_blocking(params: ListParams) -> Result<Value> {
    let roots = [
        trimmed(params.workshop_root),
        trimmed(params.legacy_workshop_root),
    ];
    let subscribed = subscribed_ids(&steam_root(params.steam_root));
    let mut seen = HashSet::new();
    let mut items = Vec::new();
    let mut cache = SizeCache::load();
    for root_text in roots {
        if root_text.is_empty() {
            continue;
        }
        let root = expand_home(root_text);
        let Ok(entries) = fs::read_dir(root) else {
            continue;
        };
        for project_dir in entries
            .filter_map(|entry| entry.ok())
            .map(|entry| entry.path())
        {
            let Ok(resolved) = project_dir.canonicalize() else {
                continue;
            };
            if !seen.insert(resolved.clone()) {
                continue;
            }
            if let Some(item) = local_project_item(&resolved, &subscribed, &mut cache) {
                items.push(item);
            }
        }
    }
    items.sort_by(|left, right| {
        let left_key = (
            integer(left.get("modified"), 0),
            text(left.get("title")).to_lowercase(),
        );
        let right_key = (
            integer(right.get("modified"), 0),
            text(right.get("title")).to_lowercase(),
        );
        right_key.cmp(&left_key)
    });
    cache.save();
    Ok(json!({"ok": true, "total": items.len(), "items": items}))
}

fn local_project_item(
    project_dir: &Path,
    subscribed: &HashSet<String>,
    cache: &mut SizeCache,
) -> Option<Value> {
    let project_file = project_dir.join("project.json");
    let published_file_id = project_dir.file_name()?.to_str()?;
    if !project_file.is_file() || !numeric_id(published_file_id) {
        return None;
    }
    let metadata: Value = serde_json::from_slice(&fs::read(&project_file).ok()?).ok()?;
    let metadata = metadata.as_object()?;
    let item_type = text(metadata.get("type")).to_lowercase();
    if UNSUPPORTED_WORKSHOP_TYPES.contains(&item_type.as_str()) {
        return None;
    }
    let tags = metadata
        .get("tags")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_string)
        .collect::<Vec<_>>();
    let preview_name = text(metadata.get("preview"));
    let preview = (!preview_name.is_empty())
        .then(|| project_dir.join(&preview_name))
        .filter(|path| path.is_file())
        .map(|path| path.display().to_string())
        .unwrap_or_default();
    let file_metadata = project_file.metadata().ok()?;
    let title = {
        let title = text(metadata.get("title"));
        if title.is_empty() {
            published_file_id.to_string()
        } else {
            title
        }
    };
    let item_type = if item_type.is_empty() {
        "unknown".to_string()
    } else {
        item_type
    };
    let resolution = cache.local_resolution(project_dir, metadata, &tags);
    let file_size = cache.directory_size(project_dir);
    Some(json!({
        "id": published_file_id,
        "title": title,
        "preview": preview,
        "type": item_type,
        "resolution": resolution,
        "tags": tags,
        "subscriptions": 0,
        "updated": modified_seconds(&file_metadata),
        "supported": true,
        "downloaded": true,
        "subscribed": subscribed.contains(published_file_id),
        "path": project_dir,
        "file_size": file_size,
        "modified": modified_millis(&file_metadata),
    }))
}

fn remove_blocking(params: RemoveParams) -> Result<Value> {
    let published_file_id = trimmed(params.id);
    let target_text = trimmed(params.path);
    if !numeric_id(&published_file_id) || target_text.is_empty() {
        return Ok(failure("invalid_file", "Invalid installed wallpaper"));
    }
    let target = expand_home(target_text);
    let Ok(resolved_target) = target.canonicalize() else {
        return Ok(failure("not_found", "Installed wallpaper was not found"));
    };
    let current_path = trimmed(params.current_path);
    if !current_path.is_empty()
        && expand_home(current_path)
            .canonicalize()
            .is_ok_and(|path| path == resolved_target)
    {
        return Ok(failure(
            "in_use",
            "Choose another wallpaper before removing this one",
        ));
    }
    let allowed_roots = [params.workshop_root, params.legacy_workshop_root]
        .into_iter()
        .flatten()
        .map(expand_home)
        .filter_map(|root| root.canonicalize().ok())
        .collect::<HashSet<_>>();
    if resolved_target.file_name().and_then(OsStr::to_str) != Some(&published_file_id)
        || resolved_target
            .parent()
            .is_none_or(|parent| !allowed_roots.contains(parent))
    {
        return Ok(failure(
            "unsafe_path",
            "Refusing to remove a path outside the Workshop folder",
        ));
    }
    if !resolved_target.join("project.json").is_file() {
        return Ok(failure(
            "missing_metadata",
            "Installed wallpaper metadata is missing",
        ));
    }
    let mut cache = SizeCache::load();
    let title = local_project_item(&resolved_target, &HashSet::new(), &mut cache)
        .and_then(|item| {
            item.get("title")
                .and_then(Value::as_str)
                .map(str::to_string)
        })
        .unwrap_or_else(|| published_file_id.clone());
    if fs::remove_dir_all(&resolved_target).is_err() {
        return Ok(failure(
            "remove_failed",
            "Could not delete the wallpaper permanently",
        ));
    }
    cache.remove(&resolved_target);
    cache.save();
    Ok(json!({
        "ok": true,
        "id": published_file_id,
        "path": resolved_target,
        "title": title,
    }))
}

fn prune_preview_cache_blocking(params: PruneParams) -> Value {
    let cache_text = trimmed(params.path);
    if cache_text.is_empty() {
        return failure("missing_path", "Preview cache path is missing");
    }
    let cache_dir = expand_home(cache_text);
    let resolved = cache_dir.canonicalize().unwrap_or(cache_dir);
    if resolved.file_name().and_then(OsStr::to_str) != Some("previews")
        || resolved
            .parent()
            .and_then(Path::file_name)
            .and_then(OsStr::to_str)
            != Some("wallpaper-engine")
    {
        return failure("unsafe_path", "Refusing to prune an unexpected cache path");
    }
    if !resolved.is_dir() {
        return json!({"ok": true, "removed": 0, "bytes_removed": 0});
    }
    let max_files = params.max_files.unwrap_or(256).clamp(16, 1024);
    let max_bytes = params
        .max_bytes
        .unwrap_or(64 * 1024 * 1024)
        .clamp(8 * 1024 * 1024, 512 * 1024 * 1024);
    let mut files = fs::read_dir(&resolved)
        .into_iter()
        .flatten()
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .extension()
                    .and_then(OsStr::to_str)
                    .is_some_and(|extension| extension.eq_ignore_ascii_case("jpg"))
        })
        .filter_map(|path| {
            let metadata = path.metadata().ok()?;
            Some((modified_millis(&metadata), metadata.len(), path))
        })
        .collect::<Vec<_>>();
    files.sort_by_key(|(modified, _, _)| std::cmp::Reverse(*modified));
    let mut kept_bytes = 0_u64;
    let mut removed = 0_u64;
    let mut bytes_removed = 0_u64;
    for (index, (_, size, path)) in files.into_iter().enumerate() {
        if index < max_files && kept_bytes.saturating_add(size) <= max_bytes {
            kept_bytes = kept_bytes.saturating_add(size);
            continue;
        }
        if fs::remove_file(path).is_ok() {
            removed += 1;
            bytes_removed = bytes_removed.saturating_add(size);
        }
    }
    json!({"ok": true, "removed": removed, "bytes_removed": bytes_removed})
}

impl SizeCache {
    fn load() -> Self {
        let entries = fs::read(size_cache_path())
            .ok()
            .and_then(|data| serde_json::from_slice::<HashMap<String, Value>>(&data).ok())
            .unwrap_or_default();
        Self {
            entries,
            dirty: false,
        }
    }

    fn save(&mut self) {
        if !self.dirty {
            return;
        }
        self.entries
            .retain(|path, value| Path::new(path).is_dir() && value.is_object());
        if write_json_atomic(&size_cache_path(), &self.entries).is_ok() {
            self.dirty = false;
        }
    }

    fn directory_size(&mut self, directory: &Path) -> u64 {
        let Ok(resolved) = directory.canonicalize() else {
            return 0;
        };
        let Ok(project) = resolved.join("project.json").metadata() else {
            return 0;
        };
        let Ok(directory_metadata) = resolved.metadata() else {
            return 0;
        };
        let signature = modified_millis(&project) ^ modified_millis(&directory_metadata);
        let key = resolved.display().to_string();
        if let Some(entry) = self.entries.get(&key).and_then(Value::as_object)
            && integer(entry.get("signature"), u64::MAX) == signature
        {
            return integer(entry.get("size"), 0);
        }
        let size = directory_size(&resolved);
        let entry = self.entry_object(&key);
        entry.insert("signature".into(), signature.into());
        entry.insert("size".into(), size.into());
        self.dirty = true;
        size
    }

    fn local_resolution(
        &mut self,
        project_dir: &Path,
        metadata: &Map<String, Value>,
        tags: &[String],
    ) -> String {
        let item_type = text(metadata.get("type")).to_lowercase();
        let project_file = project_dir.join("project.json");
        let media_name = text(metadata.get("file"));
        let mut content_path = project_dir.join(if media_name.is_empty() {
            "scene.pkg"
        } else {
            &media_name
        });
        if item_type == "scene" && !content_path.is_file() {
            content_path = project_dir.join("scene.pkg");
        }
        let signature = content_signature(&content_path, &project_file);
        let key = project_dir
            .canonicalize()
            .unwrap_or_else(|_| project_dir.to_path_buf())
            .display()
            .to_string();
        if !signature.is_empty()
            && let Some(entry) = self.entries.get(&key).and_then(Value::as_object)
            && entry.get("resolution_signature").and_then(Value::as_str) == Some(signature.as_str())
        {
            return text(entry.get("resolution"));
        }
        let mut resolution = match item_type.as_str() {
            "video" => video_resolution(&content_path),
            "scene" => scene_resolution(&content_path),
            _ => String::new(),
        };
        if resolution.is_empty() {
            resolution = wallpaper_resolution(metadata, tags);
        }
        if !signature.is_empty() {
            let entry = self.entry_object(&key);
            entry.insert("resolution_signature".into(), signature.into());
            entry.insert("resolution".into(), resolution.clone().into());
            self.dirty = true;
        }
        resolution
    }

    fn remove(&mut self, path: &Path) {
        let key = path.display().to_string();
        if self.entries.remove(&key).is_some() {
            self.dirty = true;
        }
    }

    fn entry_object(&mut self, key: &str) -> &mut Map<String, Value> {
        let value = self
            .entries
            .entry(key.to_string())
            .or_insert_with(|| json!({}));
        if !value.is_object() {
            *value = json!({});
        }
        value
            .as_object_mut()
            .expect("cache entry must be an object")
    }
}

fn subscribed_ids(steam_root: &Path) -> HashSet<String> {
    let manifest = steam_root
        .join("steamapps")
        .join("workshop")
        .join(format!("appworkshop_{APP_ID}.acf"));
    let Ok(text) = fs::read_to_string(manifest) else {
        return HashSet::new();
    };
    let Some(section_start) = text.find("\"WorkshopItemDetails\"") else {
        return HashSet::new();
    };
    SUBSCRIPTION_ENTRY_PATTERN
        .captures_iter(&text[section_start..])
        .filter(|captures| SUBSCRIBED_BY_PATTERN.is_match(&captures[2]))
        .map(|captures| captures[1].to_string())
        .collect()
}

fn installed_path(published_file_id: &str, roots: &[String]) -> Option<PathBuf> {
    roots
        .iter()
        .filter(|root| !root.is_empty())
        .find_map(|root| {
            let candidate = expand_home(root).join(published_file_id);
            candidate
                .join("project.json")
                .is_file()
                .then_some(candidate)
        })
}

fn wallpaper_type(tags: &[String]) -> String {
    let tags = tags
        .iter()
        .map(|tag| tag.to_lowercase())
        .collect::<HashSet<_>>();
    ["scene", "video", "web", "application"]
        .into_iter()
        .find(|candidate| tags.contains(*candidate))
        .unwrap_or("unknown")
        .to_string()
}

fn wallpaper_resolution(raw_item: &Map<String, Value>, tags: &[String]) -> String {
    let mut candidates = tags.to_vec();
    for key in ["metadata", "short_description", "description"] {
        let value = text(raw_item.get(key));
        if !value.is_empty() {
            candidates.push(value);
        }
    }
    candidates
        .iter()
        .find_map(|candidate| {
            let captures = RESOLUTION_PATTERN.captures(candidate)?;
            Some(format!("{}×{}", &captures[1], &captures[2]))
        })
        .unwrap_or_default()
}

fn is_nsfw_item(raw_item: &Map<String, Value>, tags: &[String]) -> bool {
    if raw_item.get("maybe_inappropriate_sex").is_some_and(truthy) {
        return true;
    }
    let descriptors = raw_item
        .get("content_descriptorids")
        .or_else(|| raw_item.get("content_descriptor_ids"));
    if descriptor_ids(descriptors)
        .iter()
        .any(|id| NSFW_CONTENT_DESCRIPTOR_IDS.contains(id))
    {
        return true;
    }
    if tags.iter().any(|tag| normalized_words(tag) == "nsfw") {
        return true;
    }
    normalized_words(&text(raw_item.get("title")))
        .split_whitespace()
        .any(|word| word == "nsfw")
}

fn descriptor_ids(value: Option<&Value>) -> Vec<u64> {
    let Some(value) = value else {
        return Vec::new();
    };
    let value = value
        .as_object()
        .and_then(|object| {
            object
                .get("ids")
                .or_else(|| object.get("content_descriptorids"))
        })
        .unwrap_or(value);
    let values = value
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_else(|| std::slice::from_ref(value));
    values
        .iter()
        .filter_map(|value| {
            let value = value
                .as_object()
                .and_then(|object| {
                    object
                        .get("id")
                        .or_else(|| object.get("content_descriptorid"))
                })
                .unwrap_or(value);
            value
                .as_u64()
                .or_else(|| value.as_str().and_then(|value| value.parse().ok()))
        })
        .collect()
}

fn normalized_tag_list(values: Vec<String>) -> Vec<String> {
    let mut seen = HashSet::new();
    values
        .into_iter()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty() && seen.insert(value.to_lowercase()))
        .collect()
}

fn normalized_words(value: &str) -> String {
    let mut result = String::with_capacity(value.len());
    let mut previous_space = true;
    for character in value.to_lowercase().chars() {
        if character.is_alphanumeric() || character == '_' || character == '+' {
            result.push(character);
            previous_space = false;
        } else if !previous_space {
            result.push(' ');
            previous_space = true;
        }
    }
    result.trim().to_string()
}

fn content_signature(content_path: &Path, project_file: &Path) -> String {
    let Ok(project) = project_file.metadata() else {
        return String::new();
    };
    let Ok(content) = content_path.metadata() else {
        return String::new();
    };
    format!(
        "{}:{}:{}:{}",
        modified_millis(&project),
        project.len(),
        modified_millis(&content),
        content.len()
    )
}

fn video_resolution(video_path: &Path) -> String {
    let Some(ffprobe) = command_path("ffprobe") else {
        return String::new();
    };
    if !video_path.is_file() {
        return String::new();
    }
    let Ok(output) = StdCommand::new(ffprobe)
        .args([
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "csv=s=x:p=0",
        ])
        .arg(video_path)
        .output()
    else {
        return String::new();
    };
    if !output.status.success() {
        return String::new();
    }
    let value = String::from_utf8_lossy(&output.stdout);
    RESOLUTION_PATTERN
        .captures(value.trim())
        .map(|captures| format!("{}×{}", &captures[1], &captures[2]))
        .unwrap_or_default()
}

fn scene_resolution(scene_path: &Path) -> String {
    let Ok(file) = fs::File::open(scene_path) else {
        return String::new();
    };
    // SAFETY: the mapping is read-only and lives no longer than the open file.
    let Ok(data) = (unsafe { Mmap::map(&file) }) else {
        return String::new();
    };
    if let Some(captures) = SCENE_HEIGHT_WIDTH_PATTERN.captures(&data) {
        return format!(
            "{}×{}",
            String::from_utf8_lossy(&captures[2]),
            String::from_utf8_lossy(&captures[1])
        );
    }
    SCENE_WIDTH_HEIGHT_PATTERN
        .captures(&data)
        .map(|captures| {
            format!(
                "{}×{}",
                String::from_utf8_lossy(&captures[1]),
                String::from_utf8_lossy(&captures[2])
            )
        })
        .unwrap_or_default()
}

fn find_downloaded_project(
    published_file_id: &str,
    steam_root: &Path,
    workshop_root: &Path,
) -> Option<PathBuf> {
    let home = std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_default();
    [
        workshop_root.join(published_file_id),
        steam_root
            .join("steamapps/workshop/content")
            .join(APP_ID)
            .join(published_file_id),
        home.join(".steam/steamcmd/steamapps/workshop/content")
            .join(APP_ID)
            .join(published_file_id),
        home.join("Steam/steamapps/workshop/content")
            .join(APP_ID)
            .join(published_file_id),
    ]
    .into_iter()
    .find(|candidate| candidate.join("project.json").is_file())
}

fn install_download(source: &Path, target: &Path) -> Result<PathBuf> {
    if source.canonicalize().ok() == target.canonicalize().ok() && source.canonicalize().is_ok() {
        return Ok(target.to_path_buf());
    }
    let parent = target.parent().context("Workshop target has no parent")?;
    fs::create_dir_all(parent)?;
    let staging = parent.join(format!(
        ".{}.download",
        target
            .file_name()
            .and_then(OsStr::to_str)
            .unwrap_or("wallpaper")
    ));
    let backup = parent.join(format!(
        ".{}.backup",
        target
            .file_name()
            .and_then(OsStr::to_str)
            .unwrap_or("wallpaper")
    ));
    let _ = fs::remove_dir_all(&staging);
    let _ = fs::remove_dir_all(&backup);
    copy_directory(source, &staging)?;
    let target_existed = target.exists();
    if target_existed {
        fs::rename(target, &backup)?;
    }
    if let Err(error) = fs::rename(&staging, target) {
        if target_existed && backup.exists() && !target.exists() {
            let _ = fs::rename(&backup, target);
        }
        let _ = fs::remove_dir_all(&staging);
        return Err(error.into());
    }
    let _ = fs::remove_dir_all(&backup);
    Ok(target.to_path_buf())
}

fn prepare_steamcmd_session() -> Result<(PathBuf, HashMap<OsString, OsString>)> {
    let data_home = std::env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/share")))
        .context("HOME or XDG_DATA_HOME is missing")?;
    let session_home = data_home.join("sownteeshell/steamcmd-home");
    let steam_state = session_home.join(".steam");
    fs::create_dir_all(&steam_state)?;
    fs::set_permissions(&session_home, fs::Permissions::from_mode(0o700))?;
    fs::set_permissions(&steam_state, fs::Permissions::from_mode(0o700))?;
    for relative in ["appcache", "config", "logs", "SteamApps/common"] {
        fs::create_dir_all(steam_state.join(relative))?;
    }
    for name in ["root", "steam"] {
        let link = steam_state.join(name);
        if fs::symlink_metadata(&link).is_err() {
            symlink(&steam_state, link)?;
        }
    }
    let shared_launcher = std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_default()
        .join(".steam/steamcmd/steamcmd.sh");
    let launcher = if shared_launcher.is_file() {
        shared_launcher
    } else {
        command_path("steamcmd").context("steamcmd is not installed")?
    };
    let mut environment = std::env::vars_os().collect::<HashMap<_, _>>();
    environment.insert(OsString::from("HOME"), session_home.into_os_string());
    Ok((launcher, environment))
}

async fn run_steamcmd(
    mut command: Command,
    cancellation: CancellationToken,
) -> SteamCommandOutcome {
    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(_) => return SteamCommandOutcome::StartFailed,
    };
    let pid = child.id().map(|pid| pid as i32);
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    let stdout_task = tokio::spawn(read_pipe(stdout));
    let stderr_task = tokio::spawn(read_pipe(stderr));
    let mut deadline = Box::pin(sleep(Duration::from_secs(1200)));
    let status = tokio::select! {
        status = child.wait() => status.ok(),
        _ = cancellation.cancelled() => {
            terminate_child_group(&mut child, pid).await;
            None
        }
        _ = &mut deadline => {
            terminate_child_group(&mut child, pid).await;
            let _ = stdout_task.await;
            let _ = stderr_task.await;
            return SteamCommandOutcome::TimedOut;
        }
    };
    let stdout = stdout_task.await.ok().flatten().unwrap_or_default();
    let stderr = stderr_task.await.ok().flatten().unwrap_or_default();
    let output = format!(
        "{}\n{}",
        String::from_utf8_lossy(&stdout),
        String::from_utf8_lossy(&stderr)
    );
    if cancellation.is_cancelled() {
        SteamCommandOutcome::Cancelled
    } else if let Some(status) = status {
        SteamCommandOutcome::Completed {
            success: status.success(),
            output,
        }
    } else {
        SteamCommandOutcome::StartFailed
    }
}

async fn read_pipe<T: tokio::io::AsyncRead + Unpin>(pipe: Option<T>) -> Option<Vec<u8>> {
    let mut pipe = pipe?;
    let mut output = VecDeque::with_capacity(MAX_STEAMCMD_PIPE_BYTES);
    let mut chunk = [0_u8; 8192];
    loop {
        let count = pipe.read(&mut chunk).await.ok()?;
        if count == 0 {
            break;
        }
        let overflow = output
            .len()
            .saturating_add(count)
            .saturating_sub(MAX_STEAMCMD_PIPE_BYTES);
        if overflow > 0 {
            output.drain(..overflow.min(output.len()));
        }
        output.extend(&chunk[..count]);
    }
    Some(output.into_iter().collect())
}

async fn terminate_child_group(child: &mut Child, pid: Option<i32>) {
    if let Some(pid) = pid {
        let _ = killpg(Pid::from_raw(pid), Signal::SIGTERM);
    } else {
        let _ = child.start_kill();
    }
    if timeout(Duration::from_secs(5), child.wait()).await.is_err() {
        if let Some(pid) = pid {
            let _ = killpg(Pid::from_raw(pid), Signal::SIGKILL);
        } else {
            let _ = child.start_kill();
        }
        let _ = timeout(Duration::from_secs(5), child.wait()).await;
    }
}

fn size_cache_path() -> PathBuf {
    let cache_home = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
        .unwrap_or_else(|| PathBuf::from("/tmp"));
    cache_home
        .join("sownteeshell")
        .join("wallpaper-workshop")
        .join("sizes.json")
}

fn steam_root(value: Option<String>) -> PathBuf {
    expand_home(value.unwrap_or_else(|| "~/.local/share/Steam".to_string()))
}

fn numeric_id(value: &str) -> bool {
    !value.is_empty() && value.bytes().all(|byte| byte.is_ascii_digit())
}

fn trimmed(value: Option<String>) -> String {
    value.unwrap_or_default().trim().to_string()
}

fn text(value: Option<&Value>) -> String {
    value
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn integer(value: Option<&Value>, fallback: u64) -> u64 {
    value
        .and_then(|value| {
            value
                .as_u64()
                .or_else(|| value.as_i64().and_then(|value| value.try_into().ok()))
                .or_else(|| value.as_str().and_then(|value| value.parse().ok()))
        })
        .unwrap_or(fallback)
}

fn truthy(value: &Value) -> bool {
    value.as_bool().unwrap_or(false)
        || value.as_u64().is_some_and(|value| value != 0)
        || value
            .as_str()
            .is_some_and(|value| matches!(value.to_lowercase().as_str(), "1" | "true" | "yes"))
}

trait StringFallback {
    fn or_id(self, value: Option<&Value>) -> String;
}

impl StringFallback for String {
    fn or_id(self, value: Option<&Value>) -> String {
        if self.is_empty() { text(value) } else { self }
    }
}

enum SteamCommandOutcome {
    Completed { success: bool, output: String },
    Cancelled,
    TimedOut,
    StartFailed,
}

struct DownloadCleanup(Vec<PathBuf>);

impl DownloadCleanup {
    fn disarm(mut self) {
        self.0.clear();
    }
}

impl Drop for DownloadCleanup {
    fn drop(&mut self) {
        let paths = std::mem::take(&mut self.0);
        if paths.is_empty() {
            return;
        }
        if let Ok(runtime) = tokio::runtime::Handle::try_current() {
            drop(runtime.spawn_blocking(move || cleanup_download_paths(paths)));
        } else {
            cleanup_download_paths(paths);
        }
    }
}

fn cleanup_download_paths(paths: Vec<PathBuf>) {
    for path in paths.into_iter().rev() {
        let _ = if path.is_dir() && !path.is_symlink() {
            fs::remove_dir_all(path)
        } else {
            fs::remove_file(path)
        };
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::AsyncWriteExt;

    #[test]
    fn detects_supported_wallpaper_type() {
        assert_eq!(wallpaper_type(&["Anime".into(), "Video".into()]), "video");
        assert_eq!(wallpaper_type(&["Web".into()]), "web");
    }

    #[test]
    fn normalizes_duplicate_tags() {
        assert_eq!(
            normalized_tag_list(vec![" Video ".into(), "video".into(), "Anime".into()]),
            vec!["Video", "Anime"]
        );
    }

    #[tokio::test]
    async fn bounds_steamcmd_pipe_output_and_keeps_the_tail() {
        let (mut writer, reader) = tokio::io::duplex(64 * 1024);
        let writer_task = tokio::spawn(async move {
            writer
                .write_all(&vec![b'a'; 4096])
                .await
                .expect("write discarded prefix");
            writer
                .write_all(&vec![b'b'; MAX_STEAMCMD_PIPE_BYTES])
                .await
                .expect("write retained tail");
        });

        let output = read_pipe(Some(reader)).await.expect("read pipe");
        writer_task.await.expect("join pipe writer");
        assert_eq!(output, vec![b'b'; MAX_STEAMCMD_PIPE_BYTES]);
    }
}
