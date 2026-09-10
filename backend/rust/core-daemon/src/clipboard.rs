use crate::command::{command_path, run_bounded, run_bounded_input_status};
use crate::job::JobRegistry;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::env;
use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;
use tokio::time::sleep;

mod favorites;
mod history;

use favorites::FavoriteStore;
use history::{ClipboardEntry, ListParams};

const CLIPBOARD_LIMIT: usize = 128 * 1024 * 1024;
const COMMAND_OUTPUT_LIMIT: usize = 256 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(20);

#[derive(Clone)]
pub struct ClipboardBackend {
    jobs: JobRegistry,
    favorites: FavoriteStore,
    favorite_lock: Arc<Mutex<()>>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RestoreParams {
    #[serde(default)]
    auto_paste: bool,
    entry_id: String,
}

impl ClipboardBackend {
    pub fn new(jobs: JobRegistry, data_dir: PathBuf) -> Self {
        Self {
            jobs,
            favorites: FavoriteStore::new(data_dir.join("clipboard/favorites")),
            favorite_lock: Arc::new(Mutex::new(())),
        }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("clipboard.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();
        let result = match method {
            "clipboard.restore" => {
                let params: RestoreParams =
                    serde_json::from_value(params).context("decode clipboard restore request")?;
                let data = if let Some(hash) = params.entry_id.strip_prefix("favorite:") {
                    let _guard = self.favorite_lock.lock().await;
                    self.favorites.read_data(hash).await
                } else {
                    decode_entry(&params.entry_id, cancellation.clone()).await
                };
                match data {
                    Ok(data) => restore(params, data, cancellation).await,
                    Err(error) => Err(error),
                }
            }
            "clipboard.list" => {
                let params: ListParams = serde_json::from_value(params)?;
                self.list(params, cancellation).await
            }
            "clipboard.favorite.add" => {
                let params: EntryParams = serde_json::from_value(params)?;
                self.add_favorite(&params.entry_id, cancellation).await
            }
            "clipboard.favorite.remove" => {
                let params: EntryParams = serde_json::from_value(params)?;
                let hash = params
                    .entry_id
                    .strip_prefix("favorite:")
                    .context("Invalid favorite ID")?;
                let _guard = self.favorite_lock.lock().await;
                self.favorites
                    .remove(hash)
                    .await
                    .map(|()| json!({"ok": true}))
            }
            _ => return Ok(None),
        };
        Ok(Some(match result {
            Ok(value) => value,
            Err(error) => json!({"ok": false, "message": error.to_string()}),
        }))
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct EntryParams {
    entry_id: String,
}

async fn decode_entry(
    entry_id: &str,
    cancellation: tokio_util::sync::CancellationToken,
) -> Result<Vec<u8>> {
    anyhow::ensure!(
        !entry_id.is_empty() && entry_id.bytes().all(|b| b.is_ascii_digit()),
        "Invalid clipboard entry ID"
    );
    let cliphist = command_path("cliphist").context("cliphist is unavailable")?;
    let decoded = run_bounded(
        &cliphist,
        &["decode", entry_id],
        COMMAND_TIMEOUT,
        cancellation.clone(),
        CLIPBOARD_LIMIT,
    )
    .await?;
    if !decoded.status.success() {
        anyhow::bail!("Could not decode the clipboard entry");
    }
    if decoded.stdout_truncated {
        anyhow::bail!("Clipboard entry exceeds the 128 MiB safety limit");
    }

    Ok(decoded.stdout)
}

async fn restore(
    params: RestoreParams,
    data: Vec<u8>,
    cancellation: tokio_util::sync::CancellationToken,
) -> Result<Value> {
    let uri_data = normalize_uri_list(&data);
    let clipboard_data = uri_data.as_deref().unwrap_or(&data);
    let wl_copy = command_path("wl-copy").context("wl-copy is unavailable")?;
    let arguments = if uri_data.is_some() {
        vec!["--type", "text/uri-list"]
    } else {
        Vec::new()
    };
    let copied = run_bounded_input_status(
        &wl_copy,
        &arguments,
        clipboard_data,
        COMMAND_TIMEOUT,
        cancellation.clone(),
    )
    .await?;
    if !copied.success() {
        anyhow::bail!("Could not copy the clipboard entry");
    }

    if params.auto_paste {
        let wtype = command_path("wtype")
            .context("Clipboard copied, but wtype is unavailable for automatic paste")?;
        tokio::select! {
            _ = cancellation.cancelled() => anyhow::bail!("Clipboard paste was cancelled"),
            _ = sleep(Duration::from_millis(400)) => {},
        }
        let pasted = run_bounded(
            &wtype,
            &["-M", "ctrl", "-k", "v", "-m", "ctrl"],
            Duration::from_secs(5),
            cancellation,
            COMMAND_OUTPUT_LIMIT,
        )
        .await
        .context("Clipboard copied, but automatic paste failed")?;
        if !pasted.status.success() {
            anyhow::bail!("Clipboard copied, but automatic paste failed");
        }
    }
    Ok(json!({
        "ok": true,
        "mimeType": if uri_data.is_some() { "text/uri-list" } else { "" },
    }))
}

fn normalize_uri_list(data: &[u8]) -> Option<Vec<u8>> {
    let text = std::str::from_utf8(data).ok()?;
    let mut values = text
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>();
    if values
        .first()
        .is_some_and(|value| matches!(value.to_ascii_lowercase().as_str(), "copy" | "cut"))
    {
        values.remove(0);
    }

    let mut uris = Vec::new();
    for value in values {
        if value.starts_with('#') {
            continue;
        }
        let path = if value.to_ascii_lowercase().starts_with("file://") {
            local_file_uri(value)?
        } else {
            expand_home(value)
        };
        if !path.is_absolute() || !path.exists() {
            return None;
        }
        uris.push(path_to_file_uri(&path));
    }
    if uris.is_empty() {
        return None;
    }
    Some(format!("{}\r\n", uris.join("\r\n")).into_bytes())
}

fn local_file_uri(value: &str) -> Option<PathBuf> {
    let remainder = value.get(7..)?;
    let path = if remainder.starts_with('/') {
        remainder
    } else {
        let (host, path) = remainder.split_once('/')?;
        if !host.is_empty() && !host.eq_ignore_ascii_case("localhost") {
            return None;
        }
        value.get(value.len() - path.len() - 1..)?
    };
    Some(PathBuf::from(percent_decode(path)?))
}

fn expand_home(value: &str) -> PathBuf {
    if value == "~" {
        return env::var_os("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(value));
    }
    if let Some(relative) = value.strip_prefix("~/")
        && let Some(home) = env::var_os("HOME")
    {
        return PathBuf::from(home).join(relative);
    }
    PathBuf::from(value)
}

fn percent_decode(value: &str) -> Option<String> {
    let bytes = value.as_bytes();
    let mut decoded = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' {
            let high = *bytes.get(index + 1)?;
            let low = *bytes.get(index + 2)?;
            decoded.push((hex(high)? << 4) | hex(low)?);
            index += 3;
        } else {
            decoded.push(bytes[index]);
            index += 1;
        }
    }
    String::from_utf8(decoded).ok()
}

fn hex(value: u8) -> Option<u8> {
    match value {
        b'0'..=b'9' => Some(value - b'0'),
        b'a'..=b'f' => Some(value - b'a' + 10),
        b'A'..=b'F' => Some(value - b'A' + 10),
        _ => None,
    }
}

fn path_to_file_uri(path: &Path) -> String {
    let mut uri = String::from("file://");
    for byte in path.as_os_str().as_bytes() {
        if is_uri_path_byte(*byte) {
            uri.push(char::from(*byte));
        } else {
            uri.push_str(&format!("%{byte:02X}"));
        }
    }
    uri
}

fn is_uri_path_byte(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'/' | b'-' | b'.' | b'_' | b'~')
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use uuid::Uuid;

    #[test]
    fn normalizes_copy_file_lists() {
        let root = env::temp_dir().join(format!("clipboard-test-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).expect("create test directory");
        let file = root.join("a file.pdf");
        fs::write(&file, b"pdf").expect("write test file");
        let input = format!("copy\n{}\n", file.display());
        let normalized = normalize_uri_list(input.as_bytes()).expect("normalize URI list");
        assert_eq!(
            String::from_utf8(normalized).expect("UTF-8 URI list"),
            format!("{}\r\n", path_to_file_uri(&file))
        );
        fs::remove_dir_all(root).expect("remove test directory");
    }

    #[test]
    fn leaves_regular_text_unchanged() {
        assert!(normalize_uri_list(b"hello world").is_none());
    }
}
