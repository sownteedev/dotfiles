use super::favorites::content_hash;
use super::*;
use std::collections::HashSet;
use tokio_util::sync::CancellationToken;

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ClipboardEntry {
    pub id: String,
    pub content: String,
    pub content_hash: String,
    pub pinned: bool,
    pub is_image: bool,
    pub character_count: i64,
    pub line_count: i64,
    pub file_count: usize,
    pub first_file: String,
    #[serde(default)]
    pub preview_path: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ListParams {
    #[serde(default)]
    query: String,
    #[serde(default = "default_limit")]
    limit: usize,
}

fn default_limit() -> usize {
    50
}

fn image_preview(content: &str) -> bool {
    content.contains("binary data") || content.contains("image/")
}

impl ClipboardEntry {
    fn from_preview(id: &str, content: &str) -> Self {
        Self {
            id: id.to_string(),
            content: content.chars().take(1000).collect(),
            content_hash: String::new(),
            pinned: false,
            is_image: image_preview(content),
            character_count: -1,
            line_count: -1,
            file_count: 0,
            first_file: String::new(),
            preview_path: String::new(),
        }
    }

    fn from_data(id: &str, content: &str, data: &[u8]) -> Self {
        let mut entry = Self::from_preview(id, content);
        entry.content_hash = content_hash(data);
        if entry.is_image {
            return entry;
        }
        let Ok(text) = std::str::from_utf8(data) else {
            entry.is_image = true;
            return entry;
        };
        entry.line_count = 0;
        entry.character_count = 0;
        let mut file_list = true;
        for line in text.lines() {
            entry.character_count += line.chars().count() as i64 + i64::from(entry.line_count > 0);
            entry.line_count += 1;
            if !file_list {
                continue;
            }
            let value = line.trim();
            if value.is_empty()
                || value.starts_with('#')
                || value.eq_ignore_ascii_case("copy")
                || value.eq_ignore_ascii_case("cut")
            {
                continue;
            }
            if value.len() <= 4096
                && (value.starts_with("file://")
                    || value.starts_with('/')
                    || value.starts_with("~/"))
            {
                entry.file_count += 1;
                if entry.first_file.is_empty() {
                    entry.first_file = value.to_string();
                }
            } else {
                entry.file_count = 0;
                entry.first_file.clear();
                file_list = false;
            }
        }
        entry
    }
}

async fn history_rows(cancellation: CancellationToken) -> Result<Vec<(String, String)>> {
    let cliphist = command_path("cliphist").context("cliphist is unavailable")?;
    let output = run_bounded(
        &cliphist,
        &["list"],
        COMMAND_TIMEOUT,
        cancellation,
        8 * 1024 * 1024,
    )
    .await?;
    anyhow::ensure!(
        output.status.success() && !output.stdout_truncated,
        "Could not read clipboard history"
    );
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter_map(|line| {
            let (id, preview) = line.split_once('\t')?;
            (!id.is_empty() && id.bytes().all(|b| b.is_ascii_digit()))
                .then(|| (id.to_string(), preview.to_string()))
        })
        .collect())
}

impl ClipboardBackend {
    pub(super) async fn list(
        &self,
        params: ListParams,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let history = history_rows(cancellation.clone()).await;
        anyhow::ensure!(
            !cancellation.is_cancelled(),
            "Clipboard search was cancelled"
        );
        let favorites = {
            let _guard = self.favorite_lock.lock().await;
            self.favorites.list().await?
        };
        let hashes = favorites
            .iter()
            .map(|entry| entry.content_hash.clone())
            .collect::<HashSet<_>>();
        let image_previews = favorites
            .iter()
            .filter(|entry| entry.is_image)
            .map(|entry| entry.content.clone())
            .collect::<HashSet<_>>();
        let query = params.query.to_lowercase();
        let limit = params.limit.clamp(1, 200);
        let mut entries = favorites
            .into_iter()
            .filter(|entry| entry.content.to_lowercase().contains(&query))
            .take(limit)
            .collect::<Vec<_>>();
        let history_error = history
            .as_ref()
            .err()
            .map(|_| "Could not read clipboard history");
        for (id, preview) in history.unwrap_or_default() {
            if entries.len() >= limit {
                break;
            }
            anyhow::ensure!(
                !cancellation.is_cancelled(),
                "Clipboard search was cancelled"
            );
            if !preview.to_lowercase().contains(&query) {
                continue;
            }
            // Decode text once for its details/hash. Large image history entries
            // only need decoding here when they might duplicate an archived image.
            let entry = if !image_preview(&preview) || image_previews.contains(&preview) {
                match decode_entry(&id, cancellation.clone()).await {
                    Ok(data) => ClipboardEntry::from_data(&id, &preview, &data),
                    Err(_) if cancellation.is_cancelled() => {
                        anyhow::bail!("Clipboard search was cancelled")
                    }
                    Err(_) => continue, // The clipboard watcher can replace an ID during a search.
                }
            } else {
                ClipboardEntry::from_preview(&id, &preview)
            };
            if !hashes.contains(&entry.content_hash) {
                entries.push(entry);
            }
        }
        Ok(json!({"ok": true, "entries": entries, "historyError": history_error}))
    }

    pub(super) async fn add_favorite(
        &self,
        id: &str,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let rows = history_rows(cancellation.clone()).await?;
        let preview = rows
            .iter()
            .find(|(row_id, _)| row_id == id)
            .map(|(_, preview)| preview)
            .context("Clipboard entry changed; reopen Clipboard and select it again")?;
        let data = decode_entry(id, cancellation.clone()).await?;
        anyhow::ensure!(
            !cancellation.is_cancelled(),
            "Saving clipboard favorite was cancelled"
        );
        let entry = ClipboardEntry::from_data(id, preview, &data);
        let _guard = self.favorite_lock.lock().await;
        let saved_id = self.favorites.add(&data, entry).await?;
        Ok(json!({"ok": true, "entryId": saved_id}))
    }
}
