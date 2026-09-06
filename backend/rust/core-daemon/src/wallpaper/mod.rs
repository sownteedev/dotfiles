mod engine;
mod util;
mod wallhaven;
mod workshop;

use crate::job::JobRegistry;
use crate::network::NetworkClient;
use anyhow::Result;
use serde_json::Value;
use std::sync::Arc;
use tokio::sync::Semaphore;

#[derive(Clone)]
pub struct WallpaperBackend {
    downloads: Arc<Semaphore>,
    jobs: JobRegistry,
    network: NetworkClient,
}

impl WallpaperBackend {
    pub fn new(network: NetworkClient, jobs: JobRegistry) -> Self {
        Self {
            downloads: Arc::new(Semaphore::new(1)),
            jobs,
            network,
        }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("wallpaper.") {
            return Ok(None);
        }

        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();

        let result = match method {
            "wallpaper.wallhaven.search" => {
                let client = self.network.client()?;
                wallhaven::search(&client, params, cancellation).await?
            }
            "wallpaper.wallhaven.collections" => {
                let client = self.network.client()?;
                wallhaven::collections(&client, params, cancellation).await?
            }
            "wallpaper.wallhaven.collection" => {
                let client = self.network.client()?;
                wallhaven::collection_items(&client, params, cancellation).await?
            }
            "wallpaper.wallhaven.download" => {
                let permit = tokio::select! {
                    _ = cancellation.cancelled() => return Ok(Some(util::failure("cancelled", "Wallpaper download was cancelled"))),
                    permit = Arc::clone(&self.downloads).acquire_owned() => permit?,
                };
                let client = self.network.client()?;
                let result = wallhaven::download(&client, params, cancellation).await?;
                drop(permit);
                result
            }
            "wallpaper.wallhaven.list" => wallhaven::list_installed(params).await?,
            "wallpaper.wallhaven.remove" => wallhaven::remove(params).await?,
            "wallpaper.workshop.search" => {
                let client = self.network.client()?;
                workshop::search(&client, params, cancellation).await?
            }
            "wallpaper.workshop.list" => workshop::list_installed(params).await?,
            "wallpaper.workshop.subscriptions" => workshop::subscriptions(params).await?,
            "wallpaper.workshop.download" => {
                let permit = tokio::select! {
                    _ = cancellation.cancelled() => return Ok(Some(util::failure("cancelled", "Wallpaper download was cancelled"))),
                    permit = Arc::clone(&self.downloads).acquire_owned() => permit?,
                };
                let result = workshop::download(params, cancellation).await?;
                drop(permit);
                result
            }
            "wallpaper.workshop.remove" => workshop::remove(params).await?,
            "wallpaper.workshop.prunePreviewCache" => workshop::prune_preview_cache(params).await?,
            "wallpaper.engine.scan" => engine::scan(params).await?,
            "wallpaper.engine.project" => engine::project(params).await?,
            "wallpaper.engine.frameProbe" => engine::frame_probe(params, cancellation).await?,
            "wallpaper.engine.preview" => engine::preview(params, cancellation).await?,
            "wallpaper.engine.cachePreview" => engine::cache_preview(params).await?,
            "wallpaper.backdrop.ensure" => engine::ensure_backdrop(params, cancellation).await?,
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}

pub fn login_workshop(username: &str) -> Result<i32> {
    workshop::login(username)
}
