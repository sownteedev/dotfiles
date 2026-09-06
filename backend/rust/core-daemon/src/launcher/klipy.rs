use crate::command::command_path;
use crate::job::JobRegistry;
use crate::network::NetworkClient;
use anyhow::{Context, Result, anyhow, bail};
use filetime::{FileTime, set_file_mtime};
use reqwest::{StatusCode, Url};
use serde::Deserialize;
use serde_json::{Map, Value, json};
use sha2::{Digest, Sha256};
use std::cmp::Reverse;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::{Duration, SystemTime};
use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use tokio::task;
use tokio::time::sleep;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const API_BASE: &str = "https://api.klipy.com/api/v1/";
const CACHE_MAX_BYTES: u64 = 256 * 1024 * 1024;
const CACHE_MAX_FILES: usize = 40;
const MAX_COPY_BYTES: u64 = 64 * 1024 * 1024;
const MAX_RESPONSE_BYTES: usize = 4 * 1024 * 1024;
const USER_AGENT: &str = "SownteeShell/1.0 KLIPY launcher";

#[derive(Clone)]
pub struct KlipyBackend {
    cache_dir: PathBuf,
    jobs: JobRegistry,
    network: NetworkClient,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SearchParams {
    #[serde(default)]
    api_key: String,
    #[serde(default)]
    kind: String,
    #[serde(default)]
    per_page: Option<i64>,
    #[serde(default)]
    query: String,
    #[serde(default)]
    request_id: i64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct CopyParams {
    #[serde(default)]
    mime: String,
    #[serde(default)]
    paste: bool,
    #[serde(default)]
    url: String,
}

impl KlipyBackend {
    pub fn new(network: NetworkClient, jobs: JobRegistry, runtime_dir: PathBuf) -> Self {
        Self {
            cache_dir: runtime_dir.join("launcher-media"),
            jobs,
            network,
        }
    }

    pub async fn search(&self, mut params: Value) -> Result<Value> {
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();
        let params: SearchParams = serde_json::from_value(params).context("decode KLIPY search")?;
        self.search_inner(params, cancellation).await
    }

    pub async fn copy(&self, mut params: Value) -> Result<Value> {
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();
        let params: CopyParams = serde_json::from_value(params).context("decode KLIPY copy")?;
        let url = match validate_media_url(&params.url) {
            Ok(url) => url,
            Err(error) => return Ok(failure("invalid_url", error.to_string())),
        };
        if !matches!(
            params.mime.as_str(),
            "image/gif" | "image/png" | "image/webp"
        ) {
            return Ok(failure("invalid_mime", "Unsupported media type"));
        }
        let Some(wl_copy) = command_path("wl-copy") else {
            return Ok(failure("missing_dependency", "wl-copy is not installed"));
        };

        let media_path = match self
            .download_media(url, &params.mime, cancellation.clone())
            .await
        {
            Ok(path) => path,
            Err(error) => return Ok(failure("copy_failed", error.to_string())),
        };
        let uri = Url::from_file_path(&media_path)
            .map_err(|_| anyhow!("could not encode copied media path"))?;
        let mut child = Command::new(wl_copy)
            .args(["--type", "text/uri-list"])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .kill_on_drop(true)
            .spawn()
            .context("start wl-copy")?;
        let mut stdin = child.stdin.take().context("open wl-copy stdin")?;
        stdin.write_all(format!("{uri}\r\n").as_bytes()).await?;
        drop(stdin);
        let status = tokio::select! {
            _ = cancellation.cancelled() => {
                let _ = child.start_kill();
                let _ = child.wait().await;
                return Ok(failure("cancelled", "Media copy was cancelled"));
            }
            result = child.wait() => result.context("wait for wl-copy")?,
        };
        if !status.success() {
            return Ok(failure("copy_failed", "Could not update the clipboard"));
        }

        if params.paste
            && let Some(wtype) = command_path("wtype")
        {
            tokio::select! {
                _ = cancellation.cancelled() => return Ok(failure("cancelled", "Media paste was cancelled")),
                _ = sleep(Duration::from_millis(400)) => {},
            }
            let _ = Command::new(wtype)
                .args(["-M", "ctrl", "-k", "v", "-m", "ctrl"])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .await;
        }
        Ok(json!({"ok": true, "path": media_path}))
    }

    async fn search_inner(
        &self,
        params: SearchParams,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let request_id = params.request_id;
        let kind = params.kind.trim().to_lowercase();
        let kind_path = match kind.as_str() {
            "gif" => "gifs",
            "sticker" => "stickers",
            _ => return Ok(search_failure(request_id, "invalid_kind", None)),
        };
        let api_key = params.api_key.trim();
        if api_key.is_empty() {
            return Ok(search_failure(request_id, "missing_api_key", None));
        }
        let query = params.query.trim();
        let per_page = params.per_page.unwrap_or(24).clamp(8, 24);
        let endpoint = if query.is_empty() {
            "trending"
        } else {
            "search"
        };
        let mut url = Url::parse(API_BASE)?;
        url.path_segments_mut()
            .map_err(|_| anyhow!("KLIPY API URL cannot contain path segments"))?
            .extend([api_key, kind_path, endpoint]);
        {
            let mut query_pairs = url.query_pairs_mut();
            query_pairs
                .append_pair("customer_id", "sownteeshell")
                .append_pair("per_page", &per_page.to_string())
                .append_pair("content_filter", "medium");
            if !query.is_empty() {
                query_pairs.append_pair("q", query);
            }
        }

        let client = self.network.client()?;
        let response = tokio::select! {
            _ = cancellation.cancelled() => return Ok(search_failure(request_id, "offline", None)),
            response = client.get(url).header(reqwest::header::USER_AGENT, USER_AGENT).timeout(Duration::from_secs(12)).send() => response,
        };
        let mut response = match response {
            Ok(response) => response,
            Err(_) => return Ok(search_failure(request_id, "offline", None)),
        };
        let status = response.status();
        if !status.is_success() {
            let error = match status {
                StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN | StatusCode::NOT_FOUND => {
                    "invalid_api_key"
                }
                StatusCode::TOO_MANY_REQUESTS => "rate_limited",
                _ => "http_error",
            };
            return Ok(search_failure(request_id, error, Some(status.as_u16())));
        }
        if validate_media_url(response.url().as_str()).is_err() {
            return Ok(search_failure(request_id, "invalid_response", None));
        }

        let mut bytes = Vec::new();
        loop {
            let chunk = tokio::select! {
                _ = cancellation.cancelled() => return Ok(search_failure(request_id, "offline", None)),
                chunk = response.chunk() => chunk,
            };
            let chunk = match chunk {
                Ok(Some(chunk)) => chunk,
                Ok(None) => break,
                Err(_) => return Ok(search_failure(request_id, "offline", None)),
            };
            if bytes.len().saturating_add(chunk.len()) > MAX_RESPONSE_BYTES {
                return Ok(search_failure(request_id, "invalid_response", None));
            }
            bytes.extend_from_slice(&chunk);
        }
        let decoded: Value = match serde_json::from_slice(&bytes) {
            Ok(value) => value,
            Err(_) => return Ok(search_failure(request_id, "invalid_response", None)),
        };
        let items = response_items(&decoded)
            .iter()
            .filter_map(|item| normalize_item(item, &kind))
            .collect::<Vec<_>>();
        Ok(json!({
            "ok": true,
            "requestId": request_id,
            "items": items,
            "trending": query.is_empty(),
        }))
    }

    async fn download_media(
        &self,
        url: Url,
        mime: &str,
        cancellation: CancellationToken,
    ) -> Result<PathBuf> {
        let extension = mime_extension(mime)?;
        let digest = format!("{:x}", Sha256::digest(url.as_str().as_bytes()));
        let target = self
            .cache_dir
            .join(format!("klipy-{}{}", &digest[..24], extension));
        let cache_dir = self.cache_dir.clone();
        let cached_target = target.clone();
        let cached_mime = mime.to_string();
        if task::spawn_blocking(move || {
            prepare_cache_dir(&cache_dir)?;
            valid_cached_media(&cached_target, &cached_mime)
        })
        .await
        .context("join KLIPY cache validation")??
        {
            prune_cache(self.cache_dir.clone(), target.clone()).await?;
            return Ok(target);
        }

        let partial = self.cache_dir.join(format!(
            ".{}.{}.part",
            target
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or("klipy"),
            Uuid::new_v4()
        ));
        let mut cleanup = PartialFile {
            keep: false,
            path: partial.clone(),
        };
        let client = self.network.client()?;
        let response = tokio::select! {
            _ = cancellation.cancelled() => bail!("media download was cancelled"),
            response = client.get(url).header(reqwest::header::USER_AGENT, USER_AGENT).timeout(Duration::from_secs(20)).send() => response,
        }
        .context("download KLIPY media")?;
        if !response.status().is_success() {
            bail!(
                "KLIPY media download failed ({})",
                response.status().as_u16()
            );
        }
        validate_media_url(response.url().as_str())?;
        if response
            .content_length()
            .is_some_and(|length| length > MAX_COPY_BYTES)
        {
            bail!("media is too large to copy");
        }

        let mut response = response;
        let mut output = tokio::fs::File::create(&partial)
            .await
            .with_context(|| format!("create {}", partial.display()))?;
        let mut copied = 0_u64;
        let mut header = Vec::with_capacity(16);
        loop {
            let chunk = tokio::select! {
                _ = cancellation.cancelled() => bail!("media download was cancelled"),
                chunk = response.chunk() => chunk.context("read KLIPY media")?,
            };
            let Some(chunk) = chunk else {
                break;
            };
            copied = copied.saturating_add(chunk.len() as u64);
            if copied > MAX_COPY_BYTES {
                bail!("media is too large to copy");
            }
            if header.len() < 16 {
                let keep = (16 - header.len()).min(chunk.len());
                header.extend_from_slice(&chunk[..keep]);
            }
            output.write_all(&chunk).await?;
        }
        output.flush().await?;
        drop(output);
        if copied == 0 || !signature_matches(&header, mime) {
            bail!("downloaded media format did not match its MIME type");
        }
        tokio::fs::set_permissions(&partial, fs::Permissions::from_mode(0o600)).await?;
        tokio::fs::rename(&partial, &target)
            .await
            .with_context(|| format!("replace {}", target.display()))?;
        cleanup.keep = true;
        prune_cache(self.cache_dir.clone(), target.clone()).await?;
        Ok(target)
    }
}

fn response_items(response: &Value) -> &[Value] {
    if let Some(items) = response
        .get("data")
        .and_then(|data| data.get("data"))
        .and_then(Value::as_array)
    {
        return items;
    }
    response
        .get("data")
        .and_then(Value::as_array)
        .map(Vec::as_slice)
        .unwrap_or_default()
}

fn normalize_item(item: &Value, kind: &str) -> Option<Value> {
    let files = item.get("file")?.as_object()?;
    let static_preview = media_variant(
        files,
        &["sm", "xs", "md", "hd"],
        &["jpg", "png", "webp", "gif"],
    );
    let animated_preview = media_variant(files, &["sm", "xs", "md", "hd"], &["gif", "webp"]);
    let gif = media_variant(files, &["md", "hd", "sm", "xs"], &["gif"]);
    let webp = media_variant(files, &["md", "hd", "sm", "xs"], &["webp"]);
    let png = media_variant(files, &["md", "hd", "sm", "xs"], &["png"]);
    let static_preview = static_preview
        .or_else(|| animated_preview.clone())
        .or_else(|| gif.clone())
        .or_else(|| webp.clone())
        .or_else(|| png.clone())?;
    if gif.is_none() && webp.is_none() && png.is_none() {
        return None;
    }
    let preferred = if kind == "gif" {
        gif.clone()
    } else {
        webp.clone()
    }
    .or_else(|| gif.clone())
    .or_else(|| webp.clone())
    .or_else(|| png.clone())?;
    let fallback_title = if kind == "gif" { "GIF" } else { "Sticker" };
    let title = item
        .get("title")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(fallback_title);
    Some(json!({
        "id": item.get("id").map(value_text).unwrap_or_default(),
        "title": title,
        "previewUrl": static_preview.url,
        "animatedUrl": animated_preview.as_ref().map(|variant| variant.url.as_str()).unwrap_or_default(),
        "gifUrl": gif.as_ref().map(|variant| variant.url.as_str()).unwrap_or_default(),
        "webpUrl": webp.as_ref().map(|variant| variant.url.as_str()).unwrap_or_default(),
        "pngUrl": png.as_ref().map(|variant| variant.url.as_str()).unwrap_or_default(),
        "preferredUrl": preferred.url,
        "preferredFormat": preferred.format,
        "width": static_preview.width,
        "height": static_preview.height,
    }))
}

#[derive(Clone)]
struct MediaVariant {
    format: String,
    height: i64,
    url: String,
    width: i64,
}

fn media_variant(
    files: &Map<String, Value>,
    qualities: &[&str],
    formats: &[&str],
) -> Option<MediaVariant> {
    for quality in qualities {
        let Some(tier) = files.get(*quality).and_then(Value::as_object) else {
            continue;
        };
        for format in formats {
            let Some(variant) = tier.get(*format).and_then(Value::as_object) else {
                continue;
            };
            let url = variant
                .get("url")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .trim();
            if validate_media_url(url).is_err() {
                continue;
            }
            return Some(MediaVariant {
                format: (*format).to_string(),
                height: safe_integer(variant.get("height")),
                url: url.to_string(),
                width: safe_integer(variant.get("width")),
            });
        }
    }
    None
}

fn safe_integer(value: Option<&Value>) -> i64 {
    value
        .and_then(|value| value.as_i64().or_else(|| value.as_str()?.parse().ok()))
        .unwrap_or_default()
}

fn value_text(value: &Value) -> String {
    value
        .as_str()
        .map(str::to_string)
        .unwrap_or_else(|| value.to_string().trim_matches('"').to_string())
}

fn validate_media_url(value: &str) -> Result<Url> {
    let url = Url::parse(value).context("invalid media URL")?;
    let hostname = url.host_str().unwrap_or_default().to_ascii_lowercase();
    if url.scheme() != "https" || !(hostname == "klipy.com" || hostname.ends_with(".klipy.com")) {
        bail!("unsupported media URL");
    }
    Ok(url)
}

fn mime_extension(mime: &str) -> Result<&'static str> {
    match mime {
        "image/gif" => Ok(".gif"),
        "image/png" => Ok(".png"),
        "image/webp" => Ok(".webp"),
        _ => bail!("unsupported media type"),
    }
}

fn signature_matches(header: &[u8], mime: &str) -> bool {
    match mime {
        "image/gif" => header.starts_with(b"GIF87a") || header.starts_with(b"GIF89a"),
        "image/png" => header.starts_with(b"\x89PNG\r\n\x1a\n"),
        "image/webp" => {
            header.len() >= 12 && header.starts_with(b"RIFF") && &header[8..12] == b"WEBP"
        }
        _ => false,
    }
}

fn prepare_cache_dir(directory: &Path) -> Result<()> {
    fs::create_dir_all(directory)
        .with_context(|| format!("create KLIPY cache {}", directory.display()))?;
    fs::set_permissions(directory, fs::Permissions::from_mode(0o700))?;
    Ok(())
}

fn valid_cached_media(path: &Path, mime: &str) -> Result<bool> {
    use std::io::Read;

    let result = (|| -> Result<bool> {
        let metadata = fs::metadata(path)?;
        if !metadata.is_file() || metadata.len() == 0 || metadata.len() > MAX_COPY_BYTES {
            return Ok(false);
        }
        let mut file = fs::File::open(path)?;
        let mut header = [0_u8; 16];
        let read = file.read(&mut header)?;
        if !signature_matches(&header[..read], mime) {
            return Ok(false);
        }
        set_file_mtime(path, FileTime::from_system_time(SystemTime::now()))?;
        Ok(true)
    })();
    match result {
        Ok(valid) => {
            if !valid {
                let _ = fs::remove_file(path);
            }
            Ok(valid)
        }
        Err(error)
            if error
                .downcast_ref::<std::io::Error>()
                .is_some_and(|io| io.kind() == std::io::ErrorKind::NotFound) =>
        {
            Ok(false)
        }
        Err(error) => {
            let _ = fs::remove_file(path);
            Err(error)
        }
    }
}

async fn prune_cache(directory: PathBuf, keep: PathBuf) -> Result<()> {
    task::spawn_blocking(move || prune_cache_blocking(&directory, &keep))
        .await
        .context("join KLIPY cache pruning")?
}

fn prune_cache_blocking(directory: &Path, keep: &Path) -> Result<()> {
    let mut entries = fs::read_dir(directory)?
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| {
            let path = entry.path();
            if path == keep
                || !matches!(
                    path.extension().and_then(|value| value.to_str()),
                    Some("gif" | "png" | "webp")
                )
            {
                return None;
            }
            let metadata = entry.metadata().ok()?;
            if !metadata.is_file() {
                return None;
            }
            Some((
                metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH),
                metadata.len(),
                path,
            ))
        })
        .collect::<Vec<_>>();
    entries.sort_by_key(|entry| Reverse(entry.0));
    let keep_size = fs::metadata(keep)
        .map(|metadata| metadata.len())
        .unwrap_or_default();
    let mut retained = usize::from(keep.exists());
    let mut bytes = keep_size;
    for (_, size, path) in entries {
        if retained < CACHE_MAX_FILES && bytes.saturating_add(size) <= CACHE_MAX_BYTES {
            retained += 1;
            bytes = bytes.saturating_add(size);
        } else {
            let _ = fs::remove_file(path);
        }
    }
    Ok(())
}

fn failure(code: &str, message: impl Into<String>) -> Value {
    json!({"ok": false, "code": code, "message": message.into()})
}

fn search_failure(request_id: i64, error: &str, status: Option<u16>) -> Value {
    let mut value = json!({"ok": false, "requestId": request_id, "error": error});
    if let Some(status) = status {
        value["status"] = status.into();
    }
    value
}

struct PartialFile {
    keep: bool,
    path: PathBuf,
}

impl Drop for PartialFile {
    fn drop(&mut self) {
        if !self.keep {
            let _ = fs::remove_file(&self.path);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_only_klipy_https_media_urls() {
        assert!(validate_media_url("https://cdn.klipy.com/file.gif").is_ok());
        assert!(validate_media_url("http://cdn.klipy.com/file.gif").is_err());
        assert!(validate_media_url("https://klipy.com.example.org/file.gif").is_err());
    }

    #[test]
    fn recognizes_supported_media_signatures() {
        assert!(signature_matches(b"GIF89a", "image/gif"));
        assert!(signature_matches(b"\x89PNG\r\n\x1a\n", "image/png"));
        assert!(signature_matches(b"RIFF1234WEBP", "image/webp"));
        assert!(!signature_matches(b"not an image", "image/webp"));
    }

    #[test]
    fn normalizes_klipy_items_like_the_previous_worker() {
        let item = json!({
            "id": 42,
            "title": "Wave",
            "file": {
                "sm": {"jpg": {"url": "https://cdn.klipy.com/preview.jpg", "width": 320, "height": 180}},
                "md": {"gif": {"url": "https://cdn.klipy.com/full.gif", "width": 640, "height": 360}}
            }
        });
        let normalized = normalize_item(&item, "gif").expect("normalize item");
        assert_eq!(normalized["id"], "42");
        assert_eq!(normalized["preferredFormat"], "gif");
        assert_eq!(
            normalized["previewUrl"],
            "https://cdn.klipy.com/preview.jpg"
        );
    }
}
