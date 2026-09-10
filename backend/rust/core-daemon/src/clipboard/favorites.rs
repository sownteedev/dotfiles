use super::{CLIPBOARD_LIMIT, ClipboardEntry};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::io::ErrorKind;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::fs;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use uuid::Uuid;

#[derive(Clone)]
pub(super) struct FavoriteStore {
    root: PathBuf,
}

#[derive(Serialize, Deserialize)]
struct SavedEntry {
    saved_at: u64,
    entry: ClipboardEntry,
}

pub(super) fn content_hash(data: &[u8]) -> String {
    format!("{:x}", Sha256::digest(data))
}

fn validate_hash(hash: &str) -> Result<()> {
    ensure!(
        hash.len() == 64
            && hash
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)),
        "Invalid favorite ID"
    );
    Ok(())
}

impl FavoriteStore {
    pub fn new(root: PathBuf) -> Self {
        Self { root }
    }

    async fn ensure_root(&self) -> Result<()> {
        fs::create_dir_all(&self.root)
            .await
            .context("Create favorite storage")?;
        fs::set_permissions(&self.root, std::fs::Permissions::from_mode(0o700)).await?;
        Ok(())
    }

    pub async fn list(&self) -> Result<Vec<ClipboardEntry>> {
        let mut directory = match fs::read_dir(&self.root).await {
            Ok(directory) => directory,
            Err(error) if error.kind() == ErrorKind::NotFound => return Ok(Vec::new()),
            Err(error) => return Err(error).context("Read favorite storage"),
        };
        let mut entries = Vec::new();
        while let Some(path) = directory.next_entry().await? {
            let name = path.file_name().to_string_lossy().into_owned();
            if validate_hash(&name).is_err() || !path.file_type().await?.is_dir() {
                continue;
            }
            // Metadata only: opening/searching favorites never loads image blobs.
            let raw = read_limited(path.path().join("entry.json"), 64 * 1024).await?;
            let mut saved: SavedEntry =
                serde_json::from_slice(&raw).context("Read favorite metadata")?;
            ensure!(
                saved.entry.content_hash == name,
                "Favorite metadata does not match its ID"
            );
            saved.entry.id = format!("favorite:{name}");
            saved.entry.pinned = true;
            if saved.entry.is_image {
                saved.entry.preview_path = super::path_to_file_uri(&path.path().join("data"));
            }
            entries.push(saved);
        }
        entries.sort_by(|a, b| {
            b.saved_at
                .cmp(&a.saved_at)
                .then_with(|| a.entry.id.cmp(&b.entry.id))
        });
        Ok(entries.into_iter().map(|saved| saved.entry).collect())
    }

    pub async fn add(&self, data: &[u8], mut entry: ClipboardEntry) -> Result<String> {
        ensure!(
            data.len() <= CLIPBOARD_LIMIT,
            "Favorite exceeds the 128 MiB safety limit"
        );
        let hash = content_hash(data);
        self.ensure_root().await?;
        let target = self.root.join(&hash);
        if fs::try_exists(target.join("entry.json")).await? {
            return Ok(format!("favorite:{hash}"));
        }
        entry.id = format!("favorite:{hash}");
        entry.content_hash = hash.clone();
        entry.pinned = true;
        entry.preview_path.clear();
        let saved = SavedEntry {
            saved_at: SystemTime::now().duration_since(UNIX_EPOCH)?.as_millis() as u64,
            entry,
        };
        let staging = self.root.join(format!(".pending-{}", Uuid::new_v4()));
        fs::DirBuilder::new().mode(0o700).create(&staging).await?;
        let result = async {
            write_private(staging.join("data"), data).await?;
            write_private(staging.join("entry.json"), &serde_json::to_vec(&saved)?).await?;
            fs::File::open(&staging).await?.sync_all().await?;
            // Commit the content and metadata together; incomplete writes are not listed.
            fs::rename(&staging, &target)
                .await
                .context("Save clipboard favorite")?;
            fs::File::open(&self.root).await?.sync_all().await?;
            Ok::<(), anyhow::Error>(())
        }
        .await;
        if result.is_err() {
            let _ = fs::remove_dir_all(&staging).await;
        }
        result?;
        Ok(format!("favorite:{hash}"))
    }

    pub async fn read_data(&self, hash: &str) -> Result<Vec<u8>> {
        validate_hash(hash)?;
        let data = read_limited(self.root.join(hash).join("data"), CLIPBOARD_LIMIT).await?;
        ensure!(content_hash(&data) == hash, "Favorite content is damaged");
        Ok(data)
    }

    pub async fn remove(&self, hash: &str) -> Result<()> {
        validate_hash(hash)?;
        let source = self.root.join(hash);
        if !fs::try_exists(&source).await? {
            return Ok(());
        }
        let removed = self.root.join(format!(".removed-{}", Uuid::new_v4()));
        fs::rename(source, &removed)
            .await
            .context("Remove clipboard favorite")?;
        fs::remove_dir_all(removed)
            .await
            .context("Remove saved favorite content")
    }
}

async fn write_private(path: PathBuf, data: &[u8]) -> Result<()> {
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(path)
        .await?;
    file.write_all(data).await?;
    file.sync_all().await?;
    Ok(())
}

async fn read_limited(path: PathBuf, limit: usize) -> Result<Vec<u8>> {
    let file = fs::File::open(path)
        .await
        .context("Open saved clipboard data")?;
    let mut data = Vec::new();
    file.take(limit as u64 + 1).read_to_end(&mut data).await?;
    ensure!(
        data.len() <= limit,
        "Saved clipboard data exceeds the safety limit"
    );
    Ok(data)
}
