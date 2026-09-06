mod catalog;
mod klipy;

use crate::job::JobRegistry;
use crate::network::NetworkClient;
use anyhow::Result;
use serde_json::Value;
use std::path::PathBuf;

#[derive(Clone)]
pub struct LauncherBackend {
    catalog: catalog::CatalogBackend,
    klipy: klipy::KlipyBackend,
}

impl LauncherBackend {
    pub fn new(network: NetworkClient, jobs: JobRegistry, runtime_dir: PathBuf) -> Self {
        Self {
            catalog: catalog::CatalogBackend::default(),
            klipy: klipy::KlipyBackend::new(network, jobs, runtime_dir),
        }
    }

    pub async fn request(&self, method: &str, params: Value) -> Result<Option<Value>> {
        let result = match method {
            "launcher.catalog.search" => self.catalog.search(params).await?,
            "launcher.catalog.release" => self.catalog.release(),
            "launcher.klipy.search" => self.klipy.search(params).await?,
            "launcher.klipy.copy" => self.klipy.copy(params).await?,
            _ if method.starts_with("launcher.") => return Ok(None),
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}
