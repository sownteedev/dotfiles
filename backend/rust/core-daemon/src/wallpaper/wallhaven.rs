use super::util::{expand_home, failure, local_path, modified_millis};
use anyhow::{Context, Result, anyhow};
use reqwest::{Client, StatusCode, Url};
use serde::Deserialize;
use serde_json::{Map, Value, json};
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::io::AsyncWriteExt;
use tokio::task;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const API_ROOT: &str = "https://wallhaven.cc/api/v1";
const API_TIMEOUT: Duration = Duration::from_secs(30);
const DOWNLOAD_TIMEOUT: Duration = Duration::from_secs(120);
const MAX_API_RESPONSE_BYTES: usize = 8 * 1024 * 1024;
const MAX_DOWNLOAD_BYTES: u64 = 256 * 1024 * 1024;
const USER_AGENT: &str = "SownteeShell-Wallhaven/1.0";
const ALLOWED_EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "webp"];
const SORTING_OPTIONS: &[&str] = &[
    "date_added",
    "relevance",
    "random",
    "views",
    "favorites",
    "toplist",
];
const TOP_RANGE_OPTIONS: &[&str] = &["1d", "3d", "1w", "1M", "3M", "6M", "1y"];

#[derive(Default, Deserialize)]
struct SearchParams {
    api_key: Option<String>,
    atleast: Option<String>,
    categories: Option<String>,
    colors: Option<String>,
    order: Option<String>,
    page: Option<u64>,
    purity: Option<String>,
    query: Option<String>,
    ratios: Option<String>,
    resolutions: Option<String>,
    seed: Option<String>,
    sorting: Option<String>,
    top_range: Option<String>,
    wallpaper_dir: Option<String>,
}

#[derive(Default, Deserialize)]
struct CollectionsParams {
    api_key: Option<String>,
}

#[derive(Default, Deserialize)]
struct CollectionParams {
    api_key: Option<String>,
    collection_id: Option<String>,
    page: Option<u64>,
    username: Option<String>,
    wallpaper_dir: Option<String>,
}

#[derive(Default, Deserialize)]
struct WallpaperDirectoryParams {
    wallpaper_dir: Option<String>,
}

#[derive(Default, Deserialize)]
struct RemoveParams {
    current_path: Option<String>,
    id: Option<String>,
    path: Option<String>,
    wallpaper_dir: Option<String>,
}

#[derive(Default, Deserialize)]
struct DownloadParams {
    id: Option<String>,
    url: Option<String>,
    wallpaper_dir: Option<String>,
}

enum DownloadPreparation {
    Existing(Value),
    Ready { partial: PathBuf, target: PathBuf },
}

pub async fn search(
    client: &Client,
    params: Value,
    cancellation: CancellationToken,
) -> Result<Value> {
    let params: SearchParams = serde_json::from_value(params).unwrap_or_default();
    let api_key = trimmed(params.api_key);
    let sorting = allowed_or(params.sorting, SORTING_OPTIONS, "toplist");
    let categories = bit_filter(params.categories.as_deref(), "111");
    let mut purity = bit_filter(params.purity.as_deref(), "110");
    if api_key.is_empty() {
        purity.replace_range(2..3, "0");
        if purity == "000" {
            purity = "100".to_string();
        }
    }
    let order = allowed_or(params.order, &["asc", "desc"], "desc");
    let top_range = allowed_or(params.top_range, TOP_RANGE_OPTIONS, "1M");
    let color = params
        .colors
        .unwrap_or_default()
        .trim_start_matches('#')
        .to_string();
    let color = if color.len() == 6 && color.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        color
    } else {
        String::new()
    };
    let seed = params.seed.unwrap_or_default();
    let seed = if seed.len() <= 32
        && !seed.is_empty()
        && seed.bytes().all(|byte| byte.is_ascii_alphanumeric())
    {
        seed
    } else {
        String::new()
    };
    let mut query = vec![
        ("q".to_string(), trimmed(params.query)),
        ("categories".to_string(), categories),
        ("purity".to_string(), purity),
        ("sorting".to_string(), sorting.clone()),
        ("order".to_string(), order),
        (
            "topRange".to_string(),
            if sorting == "toplist" {
                top_range
            } else {
                String::new()
            },
        ),
        ("atleast".to_string(), trimmed(params.atleast)),
        ("resolutions".to_string(), trimmed(params.resolutions)),
        ("ratios".to_string(), trimmed(params.ratios)),
        ("colors".to_string(), color),
        (
            "seed".to_string(),
            if sorting == "random" {
                seed
            } else {
                String::new()
            },
        ),
        (
            "page".to_string(),
            params.page.unwrap_or(1).max(1).to_string(),
        ),
    ];
    query.retain(|(_, value)| !value.is_empty());
    let response = api_get(client, "/search", &query, &api_key, cancellation).await?;
    let wallpaper_dir = wallpaper_dir(params.wallpaper_dir);
    task::spawn_blocking(move || normalize_page(response, &wallpaper_dir))
        .await
        .context("join Wallhaven response normalizer")
}

pub async fn collections(
    client: &Client,
    params: Value,
    cancellation: CancellationToken,
) -> Result<Value> {
    let params: CollectionsParams = serde_json::from_value(params).unwrap_or_default();
    let api_key = trimmed(params.api_key);
    if api_key.is_empty() {
        return Ok(failure(
            "authentication_required",
            "Add a Wallhaven API key to load collections",
        ));
    }
    let response = api_get(client, "/collections", &[], &api_key, cancellation).await?;
    if response.get("ok") == Some(&Value::Bool(false)) {
        return Ok(response);
    }
    let items = response
        .get("data")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_object)
        .map(|item| {
            json!({
                "id": integer(item.get("id")),
                "label": text(item.get("label"), "Collection"),
                "views": integer(item.get("views")),
                "public": integer(item.get("public")) == 1,
                "count": integer(item.get("count")),
            })
        })
        .collect::<Vec<_>>();
    Ok(json!({"ok": true, "items": items}))
}

pub async fn collection_items(
    client: &Client,
    params: Value,
    cancellation: CancellationToken,
) -> Result<Value> {
    let params: CollectionParams = serde_json::from_value(params).unwrap_or_default();
    let username = trimmed(params.username);
    let collection_id = trimmed(params.collection_id);
    if username.is_empty()
        || collection_id.is_empty()
        || !collection_id.bytes().all(|byte| byte.is_ascii_digit())
    {
        return Ok(failure(
            "invalid_collection",
            "Wallhaven username and collection are required",
        ));
    }
    let endpoint = collection_endpoint(&username, &collection_id)?;
    let query = vec![(
        "page".to_string(),
        params.page.unwrap_or(1).max(1).to_string(),
    )];
    let response = api_get_url(
        client,
        endpoint,
        &query,
        &trimmed(params.api_key),
        cancellation,
    )
    .await?;
    let wallpaper_dir = wallpaper_dir(params.wallpaper_dir);
    task::spawn_blocking(move || normalize_page(response, &wallpaper_dir))
        .await
        .context("join Wallhaven collection normalizer")
}

pub async fn list_installed(params: Value) -> Result<Value> {
    let params: WallpaperDirectoryParams = serde_json::from_value(params).unwrap_or_default();
    let wallpaper_dir = wallpaper_dir(params.wallpaper_dir);
    task::spawn_blocking(move || list_installed_blocking(&wallpaper_dir))
        .await
        .context("join Wallhaven installed scan")
}

pub async fn remove(params: Value) -> Result<Value> {
    let params: RemoveParams = serde_json::from_value(params).unwrap_or_default();
    task::spawn_blocking(move || remove_blocking(params))
        .await
        .context("join Wallhaven remove")
}

pub async fn download(
    client: &Client,
    params: Value,
    cancellation: CancellationToken,
) -> Result<Value> {
    let params: DownloadParams = serde_json::from_value(params).unwrap_or_default();
    let wallpaper_id = trimmed(params.id);
    let source = trimmed(params.url);
    if !valid_id(&wallpaper_id) {
        return Ok(failure("invalid_id", "Invalid Wallhaven wallpaper ID"));
    }
    let Ok(url) = Url::parse(&source) else {
        return Ok(failure(
            "invalid_url",
            "Wallhaven returned an unsafe download URL",
        ));
    };
    if url.scheme() != "https" || url.host_str() != Some("w.wallhaven.cc") {
        return Ok(failure(
            "invalid_url",
            "Wallhaven returned an unsafe download URL",
        ));
    }
    let extension = Path::new(url.path())
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();
    if !ALLOWED_EXTENSIONS.contains(&extension.as_str()) {
        return Ok(failure(
            "unsupported_file",
            "Unsupported Wallhaven image format",
        ));
    }

    let wallpaper_dir = wallpaper_dir(params.wallpaper_dir);
    let directory_for_prepare = wallpaper_dir.clone();
    let id_for_prepare = wallpaper_id.clone();
    let extension_for_prepare = extension.clone();
    let prepared = task::spawn_blocking(move || {
        prepare_download(
            &directory_for_prepare,
            &id_for_prepare,
            &extension_for_prepare,
        )
    })
    .await
    .context("join Wallhaven download preparation")??;
    let (target, partial) = match prepared {
        DownloadPreparation::Existing(value) => return Ok(value),
        DownloadPreparation::Ready { partial, target } => (target, partial),
    };
    let cleanup = PartialFile(partial.clone());
    let response = tokio::select! {
        _ = cancellation.cancelled() => return Ok(failure("cancelled", "Wallhaven download was cancelled")),
        response = client.get(url).header(reqwest::header::USER_AGENT, USER_AGENT).timeout(DOWNLOAD_TIMEOUT).send() => response,
    };
    let mut response = match response {
        Ok(response) if response.status().is_success() => response,
        Ok(response) => {
            return Ok(failure(
                "download_failed",
                format!("Wallhaven download failed ({})", response.status().as_u16()),
            ));
        }
        Err(_) => {
            return Ok(failure(
                "download_failed",
                "Could not download the Wallhaven image",
            ));
        }
    };
    if response
        .content_length()
        .is_some_and(|length| length > MAX_DOWNLOAD_BYTES)
    {
        return Ok(failure(
            "download_too_large",
            "Wallhaven image exceeds the 256 MiB download limit",
        ));
    }
    let mut output = tokio::fs::File::create(&partial)
        .await
        .with_context(|| format!("create {}", partial.display()))?;
    let mut downloaded = 0_u64;
    loop {
        let chunk = tokio::select! {
            _ = cancellation.cancelled() => return Ok(failure("cancelled", "Wallhaven download was cancelled")),
            chunk = response.chunk() => chunk,
        };
        match chunk {
            Ok(Some(chunk)) => {
                downloaded = downloaded.saturating_add(chunk.len() as u64);
                if downloaded > MAX_DOWNLOAD_BYTES {
                    return Ok(failure(
                        "download_too_large",
                        "Wallhaven image exceeds the 256 MiB download limit",
                    ));
                }
                output.write_all(&chunk).await?;
            }
            Ok(None) => break,
            Err(_) => {
                return Ok(failure(
                    "download_failed",
                    "Could not download the Wallhaven image",
                ));
            }
        }
    }
    output.flush().await?;
    drop(output);
    if downloaded == 0 {
        return Ok(failure(
            "download_failed",
            "Could not download the Wallhaven image",
        ));
    }
    tokio::fs::rename(&partial, &target)
        .await
        .with_context(|| format!("install {}", target.display()))?;
    cleanup.disarm();
    let resolved = tokio::fs::canonicalize(&target).await.unwrap_or(target);
    let metadata = tokio::fs::metadata(&resolved).await?;
    Ok(json!({
        "ok": true,
        "id": wallpaper_id,
        "path": resolved,
        "modified": modified_millis(&metadata),
        "file_size": metadata.len(),
        "existing": false,
    }))
}

fn prepare_download(
    wallpaper_dir: &Path,
    wallpaper_id: &str,
    extension: &str,
) -> Result<DownloadPreparation> {
    fs::create_dir_all(wallpaper_dir)
        .with_context(|| format!("create {}", wallpaper_dir.display()))?;
    if let Some(existing) = local_wallpaper(wallpaper_dir, wallpaper_id) {
        let metadata = existing.metadata()?;
        return Ok(DownloadPreparation::Existing(json!({
            "ok": true,
            "id": wallpaper_id,
            "path": existing,
            "modified": modified_millis(&metadata),
            "file_size": metadata.len(),
            "existing": true,
        })));
    }

    let target = wallpaper_dir.join(format!("wallhaven-{wallpaper_id}.{extension}"));
    if fs::symlink_metadata(&target).is_ok() {
        return Ok(DownloadPreparation::Existing(failure(
            "unsafe_path",
            "Refusing to overwrite an unexpected wallpaper file",
        )));
    }
    let partial = wallpaper_dir.join(format!(".wallhaven-{wallpaper_id}.{}.part", Uuid::new_v4()));
    Ok(DownloadPreparation::Ready { partial, target })
}

async fn api_get(
    client: &Client,
    endpoint: &str,
    parameters: &[(String, String)],
    api_key: &str,
    cancellation: CancellationToken,
) -> Result<Value> {
    let url = Url::parse(&format!("{API_ROOT}{endpoint}"))?;
    api_get_url(client, url, parameters, api_key, cancellation).await
}

async fn api_get_url(
    client: &Client,
    mut url: Url,
    parameters: &[(String, String)],
    api_key: &str,
    cancellation: CancellationToken,
) -> Result<Value> {
    {
        let mut query = url.query_pairs_mut();
        for (key, value) in parameters {
            if !value.is_empty() {
                query.append_pair(key, value);
            }
        }
    }
    let mut request = client
        .get(url)
        .header(reqwest::header::ACCEPT, "application/json")
        .header(reqwest::header::USER_AGENT, USER_AGENT)
        .timeout(API_TIMEOUT);
    if !api_key.is_empty() {
        request = request.header("X-API-Key", api_key);
    }
    let response = tokio::select! {
        _ = cancellation.cancelled() => return Ok(failure("cancelled", "Wallhaven request was cancelled")),
        response = request.send() => response,
    };
    let mut response = match response {
        Ok(response) => response,
        Err(_) => return Ok(failure("network_error", "Could not reach Wallhaven")),
    };
    if !response.status().is_success() {
        return Ok(match response.status() {
            StatusCode::UNAUTHORIZED => {
                failure("authentication_required", "Wallhaven rejected the API key")
            }
            StatusCode::FORBIDDEN => failure(
                "authentication_required",
                "This Wallhaven content needs account access",
            ),
            StatusCode::NOT_FOUND => failure("not_found", "Wallhaven could not find this resource"),
            StatusCode::TOO_MANY_REQUESTS => failure(
                "rate_limited",
                "Wallhaven rate limit reached; wait a moment and try again",
            ),
            status => failure(
                "http_error",
                format!("Wallhaven request failed ({})", status.as_u16()),
            ),
        });
    }
    if response
        .content_length()
        .is_some_and(|length| length > MAX_API_RESPONSE_BYTES as u64)
    {
        return Ok(failure(
            "response_too_large",
            "Wallhaven response exceeded 8 MiB",
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
            _ = cancellation.cancelled() => return Ok(failure("cancelled", "Wallhaven request was cancelled")),
            chunk = response.chunk() => chunk,
        };
        match chunk {
            Ok(Some(chunk)) => {
                if bytes.len().saturating_add(chunk.len()) > MAX_API_RESPONSE_BYTES {
                    return Ok(failure(
                        "response_too_large",
                        "Wallhaven response exceeded 8 MiB",
                    ));
                }
                bytes.extend_from_slice(&chunk);
            }
            Ok(None) => break,
            Err(_) => {
                return Ok(failure(
                    "invalid_response",
                    "Wallhaven returned unreadable data",
                ));
            }
        }
    }
    Ok(serde_json::from_slice::<Value>(&bytes)
        .unwrap_or_else(|_| failure("invalid_response", "Wallhaven returned unreadable data")))
}

fn collection_endpoint(username: &str, collection_id: &str) -> Result<Url> {
    let mut url = Url::parse(API_ROOT)?;
    url.path_segments_mut()
        .map_err(|_| anyhow!("Wallhaven API URL cannot contain path segments"))?
        .extend(["collections", username, collection_id]);
    Ok(url)
}

fn normalize_page(response: Value, wallpaper_dir: &Path) -> Value {
    if response.get("ok") == Some(&Value::Bool(false)) {
        return response;
    }
    let items = response
        .get("data")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_object)
        .map(|item| normalize_wallpaper(item, wallpaper_dir))
        .collect::<Vec<_>>();
    let meta = response.get("meta").and_then(Value::as_object);
    let item_count = items.len() as u64;
    json!({
        "ok": true,
        "items": items,
        "current_page": integer(meta.and_then(|value| value.get("current_page"))).max(1),
        "last_page": integer(meta.and_then(|value| value.get("last_page"))).max(1),
        "total": meta.and_then(|value| value.get("total")).map(|value| integer(Some(value))).unwrap_or(item_count),
        "seed": meta.and_then(|value| value.get("seed")).and_then(Value::as_str).unwrap_or_default(),
    })
}

fn normalize_wallpaper(item: &Map<String, Value>, wallpaper_dir: &Path) -> Value {
    let wallpaper_id = text(item.get("id"), "");
    let local_path = local_wallpaper(wallpaper_dir, &wallpaper_id);
    let thumbs = item.get("thumbs").and_then(Value::as_object);
    let modified = local_path
        .as_ref()
        .and_then(|path| path.metadata().ok())
        .map(|metadata| modified_millis(&metadata))
        .unwrap_or(0);
    json!({
        "id": wallpaper_id,
        "url": text(item.get("url"), ""),
        "full": text(item.get("path"), ""),
        "preview": thumbs.and_then(|value| value.get("large").or_else(|| value.get("original")).or_else(|| value.get("small"))).and_then(Value::as_str).unwrap_or_default(),
        "thumb": thumbs.and_then(|value| value.get("small").or_else(|| value.get("original"))).and_then(Value::as_str).unwrap_or_default(),
        "category": text(item.get("category"), "general"),
        "purity": text(item.get("purity"), "sfw"),
        "nsfw": text(item.get("purity"), "").eq_ignore_ascii_case("nsfw"),
        "resolution": text(item.get("resolution"), ""),
        "width": integer(item.get("dimension_x")),
        "height": integer(item.get("dimension_y")),
        "ratio": text(item.get("ratio"), ""),
        "file_size": integer(item.get("file_size")),
        "file_type": text(item.get("file_type"), ""),
        "views": integer(item.get("views")),
        "favorites": integer(item.get("favorites")),
        "source": text(item.get("source"), ""),
        "created_at": text(item.get("created_at"), ""),
        "downloaded": local_path.is_some(),
        "path": local_path.unwrap_or_default(),
        "modified": modified,
    })
}

fn list_installed_blocking(wallpaper_dir: &Path) -> Value {
    if !wallpaper_dir.is_dir() {
        return json!({"ok": true, "items": []});
    }
    let Ok(entries) = fs::read_dir(wallpaper_dir) else {
        return failure("list_failed", "Could not read the wallpaper folder");
    };
    let mut items = entries
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| local_item(&entry.path(), wallpaper_dir))
        .collect::<Vec<_>>();
    items.sort_by_key(|item| std::cmp::Reverse(integer(item.get("modified"))));
    json!({"ok": true, "items": items})
}

fn remove_blocking(params: RemoveParams) -> Value {
    let wallpaper_id = trimmed(params.id);
    let target_text = trimmed(params.path);
    if !valid_id(&wallpaper_id) || target_text.is_empty() {
        return failure("invalid_file", "Invalid installed Wallhaven wallpaper");
    }
    let wallpaper_dir = wallpaper_dir(params.wallpaper_dir);
    let target = local_path(&target_text);
    if target
        .symlink_metadata()
        .is_ok_and(|metadata| metadata.file_type().is_symlink())
    {
        return failure("unsafe_path", "Refusing to remove a symbolic link");
    }
    let Ok(root) = wallpaper_dir.canonicalize() else {
        return failure("not_found", "Installed wallpaper was not found");
    };
    let Ok(resolved) = target.canonicalize() else {
        return failure("not_found", "Installed wallpaper was not found");
    };
    let Some(installed_id) = local_name_id(&resolved) else {
        return failure(
            "unsafe_path",
            "Refusing to remove a file outside the Wallhaven wallpaper folder",
        );
    };
    if installed_id != wallpaper_id
        || resolved.parent() != Some(root.as_path())
        || !resolved.is_file()
    {
        return failure(
            "unsafe_path",
            "Refusing to remove a file outside the Wallhaven wallpaper folder",
        );
    }
    let current_path = trimmed(params.current_path);
    if !current_path.is_empty()
        && local_path(current_path)
            .canonicalize()
            .is_ok_and(|path| path == resolved)
    {
        return failure(
            "in_use",
            "Choose another wallpaper before deleting this one",
        );
    }
    let removed_size = resolved
        .metadata()
        .map(|metadata| metadata.len())
        .unwrap_or(0);
    if fs::remove_file(&resolved).is_err() {
        return failure(
            "remove_failed",
            "Could not delete the wallpaper permanently",
        );
    }
    json!({
        "ok": true,
        "id": wallpaper_id,
        "path": resolved,
        "title": format!("wallhaven-{wallpaper_id}"),
        "bytes_removed": removed_size,
    })
}

fn local_item(path: &Path, wallpaper_dir: &Path) -> Option<Value> {
    let wallpaper_id = local_name_id(path)?;
    let metadata = path.symlink_metadata().ok()?;
    if metadata.file_type().is_symlink() || !metadata.is_file() {
        return None;
    }
    let root = wallpaper_dir.canonicalize().ok()?;
    let resolved = path.canonicalize().ok()?;
    if resolved.parent()? != root || !allowed_extension(&resolved) {
        return None;
    }
    let (width, height) = image_dimensions(&resolved);
    let resolution = if width > 0 && height > 0 {
        format!("{width}x{height}")
    } else {
        String::new()
    };
    Some(json!({
        "id": wallpaper_id,
        "url": format!("https://wallhaven.cc/w/{wallpaper_id}"),
        "full": "",
        "preview": resolved,
        "thumb": resolved,
        "category": "local",
        "purity": "",
        "nsfw": false,
        "resolution": resolution,
        "width": width,
        "height": height,
        "ratio": "",
        "file_size": metadata.len(),
        "file_type": resolved.extension().and_then(|value| value.to_str()).unwrap_or_default().to_ascii_lowercase(),
        "views": 0,
        "favorites": 0,
        "source": "",
        "created_at": "",
        "downloaded": true,
        "path": resolved,
        "modified": modified_millis(&metadata),
    }))
}

fn local_wallpaper(wallpaper_dir: &Path, wallpaper_id: &str) -> Option<PathBuf> {
    if !wallpaper_dir.is_dir() || !valid_id(wallpaper_id) {
        return None;
    }
    let root = wallpaper_dir.canonicalize().ok()?;
    fs::read_dir(wallpaper_dir)
        .ok()?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .find_map(|candidate| {
            let metadata = candidate.symlink_metadata().ok()?;
            if metadata.file_type().is_symlink()
                || !metadata.is_file()
                || local_name_id(&candidate).as_deref() != Some(wallpaper_id)
                || !allowed_extension(&candidate)
            {
                return None;
            }
            let resolved = candidate.canonicalize().ok()?;
            (resolved.parent() == Some(root.as_path())).then_some(resolved)
        })
}

fn local_name_id(path: &Path) -> Option<String> {
    let extension = path.extension()?.to_str()?.to_ascii_lowercase();
    if !ALLOWED_EXTENSIONS.contains(&extension.as_str()) {
        return None;
    }
    let stem = path.file_stem()?.to_str()?;
    let wallpaper_id = stem.strip_prefix("wallhaven-")?;
    valid_id(wallpaper_id).then(|| wallpaper_id.to_string())
}

fn image_dimensions(path: &Path) -> (u32, u32) {
    let Ok(mut file) = fs::File::open(path) else {
        return (0, 0);
    };
    let mut data = Vec::with_capacity(131_072);
    if file.by_ref().take(131_072).read_to_end(&mut data).is_err() {
        return (0, 0);
    }
    if data.starts_with(b"\x89PNG\r\n\x1a\n") && data.len() >= 24 {
        return (
            u32::from_be_bytes(data[16..20].try_into().unwrap_or_default()),
            u32::from_be_bytes(data[20..24].try_into().unwrap_or_default()),
        );
    }
    if data.starts_with(b"\xff\xd8") {
        let mut offset = 2;
        while offset + 9 < data.len() {
            if data[offset] != 0xff {
                offset += 1;
                continue;
            }
            let marker = data[offset + 1];
            offset += 2;
            if matches!(marker, 0xd8 | 0xd9) || (0xd0..=0xd7).contains(&marker) {
                continue;
            }
            if offset + 2 > data.len() {
                break;
            }
            let segment_length = u16::from_be_bytes([data[offset], data[offset + 1]]) as usize;
            if matches!(
                marker,
                0xc0 | 0xc1
                    | 0xc2
                    | 0xc3
                    | 0xc5
                    | 0xc6
                    | 0xc7
                    | 0xc9
                    | 0xca
                    | 0xcb
                    | 0xcd
                    | 0xce
                    | 0xcf
            ) && offset + 7 <= data.len()
            {
                let height = u16::from_be_bytes([data[offset + 3], data[offset + 4]]);
                let width = u16::from_be_bytes([data[offset + 5], data[offset + 6]]);
                return (u32::from(width), u32::from(height));
            }
            if segment_length < 2 {
                break;
            }
            offset = offset.saturating_add(segment_length);
        }
    }
    if data.len() >= 30 && &data[..4] == b"RIFF" && &data[8..12] == b"WEBP" {
        match &data[12..16] {
            b"VP8X" => {
                let width = 1 + u32::from_le_bytes([data[24], data[25], data[26], 0]);
                let height = 1 + u32::from_le_bytes([data[27], data[28], data[29], 0]);
                return (width, height);
            }
            b"VP8L" if data[20] == 0x2f => {
                let width = 1 + u32::from(data[21]) + (u32::from(data[22] & 0x3f) << 8);
                let height = 1
                    + u32::from(data[22] >> 6)
                    + (u32::from(data[23]) << 2)
                    + (u32::from(data[24] & 0x0f) << 10);
                return (width, height);
            }
            b"VP8 " if &data[23..26] == b"\x9d\x01\x2a" => {
                let width = u16::from_le_bytes([data[26], data[27]]) & 0x3fff;
                let height = u16::from_le_bytes([data[28], data[29]]) & 0x3fff;
                return (u32::from(width), u32::from(height));
            }
            _ => {}
        }
    }
    (0, 0)
}

fn wallpaper_dir(value: Option<String>) -> PathBuf {
    expand_home(value.unwrap_or_else(|| "~/Pictures/Wallpapers".to_string()))
}

fn valid_id(value: &str) -> bool {
    (2..=16).contains(&value.len()) && value.bytes().all(|byte| byte.is_ascii_alphanumeric())
}

fn allowed_extension(path: &Path) -> bool {
    path.extension()
        .and_then(|value| value.to_str())
        .map(str::to_ascii_lowercase)
        .is_some_and(|value| ALLOWED_EXTENSIONS.contains(&value.as_str()))
}

fn bit_filter(value: Option<&str>, fallback: &str) -> String {
    value
        .filter(|value| {
            value.len() == 3
                && value != &"000"
                && value.bytes().all(|byte| matches!(byte, b'0' | b'1'))
        })
        .unwrap_or(fallback)
        .to_string()
}

fn allowed_or(value: Option<String>, allowed: &[&str], fallback: &str) -> String {
    value
        .filter(|value| allowed.contains(&value.as_str()))
        .unwrap_or_else(|| fallback.to_string())
}

fn trimmed(value: Option<String>) -> String {
    value.unwrap_or_default().trim().to_string()
}

fn integer(value: Option<&Value>) -> u64 {
    value
        .and_then(|value| {
            value
                .as_u64()
                .or_else(|| value.as_i64().and_then(|value| value.try_into().ok()))
                .or_else(|| value.as_str().and_then(|value| value.parse().ok()))
        })
        .unwrap_or(0)
}

fn text(value: Option<&Value>, fallback: &str) -> String {
    value
        .and_then(Value::as_str)
        .unwrap_or(fallback)
        .to_string()
}

struct PartialFile(PathBuf);

impl PartialFile {
    fn disarm(mut self) {
        self.0 = PathBuf::new();
    }
}

impl Drop for PartialFile {
    fn drop(&mut self) {
        if !self.0.as_os_str().is_empty() {
            let _ = fs::remove_file(&self.0);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_wallhaven_identifiers() {
        assert!(valid_id("abc123"));
        assert!(!valid_id("a"));
        assert!(!valid_id("../../etc"));
    }

    #[test]
    fn filters_wallhaven_bits() {
        assert_eq!(bit_filter(Some("101"), "111"), "101");
        assert_eq!(bit_filter(Some("000"), "111"), "111");
        assert_eq!(bit_filter(Some("12"), "111"), "111");
    }

    #[test]
    fn encodes_collection_username_as_one_path_segment() {
        let url = collection_endpoint("name/with space", "42").expect("collection URL");
        assert_eq!(
            url.as_str(),
            "https://wallhaven.cc/api/v1/collections/name%2Fwith%20space/42"
        );
    }
}
