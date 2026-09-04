use anyhow::{Context, Result};
use secret_service::{EncryptionType, SecretService};
use serde::Serialize;
use serde::de::DeserializeOwned;
use std::collections::HashMap;

const APPLICATION_ATTRIBUTE: &str = "sownteeshell-calendar";

#[derive(Clone, Debug, Default)]
pub struct Keyring;

impl Keyring {
    pub async fn available(&self) -> bool {
        SecretService::connect(EncryptionType::Dh).await.is_ok()
    }

    pub async fn get(&self, account_id: &str, key: &str) -> Result<Option<Vec<u8>>> {
        let service = connect().await?;
        let search = service
            .search_items(attributes(account_id, Some(key)))
            .await
            .context("search Secret Service items")?;

        if let Some(item) = search.unlocked.first() {
            return item
                .get_secret()
                .await
                .map(Some)
                .context("read Secret Service item");
        }

        if let Some(item) = search.locked.first() {
            item.unlock().await.context("unlock Secret Service item")?;
            return item
                .get_secret()
                .await
                .map(Some)
                .context("read unlocked Secret Service item");
        }

        Ok(None)
    }

    pub async fn get_text(&self, account_id: &str, key: &str) -> Result<Option<String>> {
        self.get(account_id, key)
            .await?
            .map(String::from_utf8)
            .transpose()
            .context("Secret Service item is not valid UTF-8")
    }

    pub async fn get_json<T: DeserializeOwned>(
        &self,
        account_id: &str,
        key: &str,
    ) -> Result<Option<T>> {
        self.get(account_id, key)
            .await?
            .map(|bytes| serde_json::from_slice(&bytes))
            .transpose()
            .context("decode JSON from Secret Service")
    }

    pub async fn set(&self, account_id: &str, key: &str, secret: &[u8]) -> Result<()> {
        let service = connect().await?;
        let collection = service
            .get_default_collection()
            .await
            .context("open default Secret Service collection")?;
        if collection
            .is_locked()
            .await
            .context("read Secret Service collection state")?
        {
            collection
                .unlock()
                .await
                .context("unlock Secret Service collection")?;
        }

        let label = format!("SownteeShell Calendar: {account_id} ({key})");
        collection
            .create_item(
                &label,
                attributes(account_id, Some(key)),
                secret,
                true,
                "application/octet-stream",
            )
            .await
            .context("write Secret Service item")?;
        Ok(())
    }

    pub async fn set_text(&self, account_id: &str, key: &str, value: &str) -> Result<()> {
        self.set(account_id, key, value.as_bytes()).await
    }

    pub async fn set_json<T: Serialize>(
        &self,
        account_id: &str,
        key: &str,
        value: &T,
    ) -> Result<()> {
        self.set(account_id, key, &serde_json::to_vec(value)?).await
    }

    pub async fn delete(&self, account_id: &str, key: &str) -> Result<()> {
        let service = connect().await?;
        let search = service
            .search_items(attributes(account_id, Some(key)))
            .await
            .context("search Secret Service items")?;
        for item in search.unlocked {
            item.delete().await.context("delete Secret Service item")?;
        }
        for item in search.locked {
            item.unlock().await.context("unlock Secret Service item")?;
            item.delete().await.context("delete Secret Service item")?;
        }
        Ok(())
    }

    pub async fn delete_account(&self, account_id: &str) -> Result<()> {
        let service = connect().await?;
        let search = service
            .search_items(attributes(account_id, None))
            .await
            .context("search account secrets")?;
        for item in search.unlocked {
            item.delete().await.context("delete account secret")?;
        }
        for item in search.locked {
            item.unlock().await.context("unlock account secret")?;
            item.delete().await.context("delete account secret")?;
        }
        Ok(())
    }
}

async fn connect() -> Result<SecretService<'static>> {
    SecretService::connect(EncryptionType::Dh)
        .await
        .context("connect to org.freedesktop.secrets")
}

fn attributes<'a>(account_id: &'a str, key: Option<&'a str>) -> HashMap<&'a str, &'a str> {
    let mut attributes = HashMap::from([
        ("application", APPLICATION_ATTRIBUTE),
        ("account", account_id),
    ]);
    if let Some(key) = key {
        attributes.insert("key", key);
    }
    attributes
}
