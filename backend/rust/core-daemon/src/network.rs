use anyhow::{Context, Result};
use reqwest::Client;
use std::sync::{Arc, OnceLock};
use std::time::Duration;

#[derive(Clone, Default)]
pub struct NetworkClient {
    client: Arc<OnceLock<Client>>,
}

impl NetworkClient {
    pub fn client(&self) -> Result<Client> {
        if let Some(client) = self.client.get() {
            return Ok(client.clone());
        }

        let client = Client::builder()
            .connect_timeout(Duration::from_secs(10))
            .pool_idle_timeout(Duration::from_secs(45))
            .pool_max_idle_per_host(2)
            .redirect(reqwest::redirect::Policy::limited(5))
            .timeout(Duration::from_secs(35))
            .build()
            .context("create shared HTTP client")?;
        let _ = self.client.set(client);
        self.client
            .get()
            .cloned()
            .context("initialize shared HTTP client")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lazily_reuses_the_http_client() {
        let network = NetworkClient::default();
        let first = network.client().expect("create first client");
        let second = network.client().expect("reuse client");
        assert_eq!(format!("{first:?}"), format!("{second:?}"));
    }
}
