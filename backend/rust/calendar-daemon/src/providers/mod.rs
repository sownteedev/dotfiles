pub mod caldav;
pub mod google;
pub mod microsoft;

use crate::keyring::Keyring;
use crate::model::{
    Account, Calendar, CalendarEvent, EventDraft, ProviderKind, RemoteCalendar, SyncBatch,
};
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use reqwest::Client;
use std::sync::Arc;
use thiserror::Error;

pub const OAUTH_TOKEN_KEY: &str = "oauth-token";
pub const OAUTH_CLIENT_SECRET_KEY: &str = "oauth-client-secret";
pub const CALDAV_PASSWORD_KEY: &str = "caldav-password";

#[derive(Debug, Error)]
pub enum ProviderError {
    #[error("reauthentication required: {0}")]
    Reauth(String),
    #[error("sync cursor expired: {0}")]
    CursorExpired(String),
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

impl From<reqwest::Error> for ProviderError {
    fn from(error: reqwest::Error) -> Self {
        Self::Other(error.into())
    }
}

impl From<serde_json::Error> for ProviderError {
    fn from(error: serde_json::Error) -> Self {
        Self::Other(error.into())
    }
}

impl From<url::ParseError> for ProviderError {
    fn from(error: url::ParseError) -> Self {
        Self::Other(error.into())
    }
}

pub type ProviderResult<T> = Result<T, ProviderError>;

#[derive(Clone, Copy, Debug)]
pub struct SyncWindow {
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
}

#[async_trait]
pub trait CalendarProvider: Send + Sync {
    fn kind(&self) -> ProviderKind;

    async fn list_calendars(&self, account: &Account) -> ProviderResult<Vec<RemoteCalendar>>;

    async fn sync_calendar(
        &self,
        account: &Account,
        calendar: &Calendar,
        window: SyncWindow,
    ) -> ProviderResult<SyncBatch>;

    async fn create_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        draft: &EventDraft,
    ) -> ProviderResult<CalendarEvent>;

    async fn update_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        event: &CalendarEvent,
        draft: &EventDraft,
    ) -> ProviderResult<CalendarEvent>;

    async fn delete_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        event: &CalendarEvent,
    ) -> ProviderResult<()>;
}

#[derive(Clone)]
pub struct ProviderRegistry {
    http: Client,
    google: Arc<google::GoogleProvider>,
    microsoft: Arc<microsoft::MicrosoftProvider>,
    caldav: Arc<caldav::CalDavProvider>,
}

impl ProviderRegistry {
    pub fn new(keyring: Keyring) -> anyhow::Result<Self> {
        let http = Client::builder()
            .user_agent(format!(
                "SownteeCalendar/{} (+https://github.com/nguyenthanhson)",
                env!("CARGO_PKG_VERSION")
            ))
            .connect_timeout(std::time::Duration::from_secs(15))
            .timeout(std::time::Duration::from_secs(45))
            .build()?;
        Ok(Self {
            http: http.clone(),
            google: Arc::new(google::GoogleProvider::new(http.clone(), keyring.clone())),
            microsoft: Arc::new(microsoft::MicrosoftProvider::new(
                http.clone(),
                keyring.clone(),
            )),
            caldav: Arc::new(caldav::CalDavProvider::new(http, keyring)),
        })
    }

    pub fn http(&self) -> Client {
        self.http.clone()
    }

    pub fn get(&self, kind: ProviderKind) -> Arc<dyn CalendarProvider> {
        match kind {
            ProviderKind::Google => self.google.clone(),
            ProviderKind::Microsoft => self.microsoft.clone(),
            ProviderKind::CalDav => self.caldav.clone(),
        }
    }
}

pub(crate) fn is_reauth_status(status: reqwest::StatusCode) -> bool {
    status == reqwest::StatusCode::UNAUTHORIZED
}

pub(crate) async fn response_error(response: reqwest::Response) -> String {
    let status = response.status();
    let body = response.text().await.unwrap_or_default();
    if let Ok(value) = serde_json::from_str::<serde_json::Value>(&body) {
        let message = value
            .pointer("/error/message")
            .or_else(|| value.pointer("/error/errors/0/message"))
            .and_then(|value| value.as_str())
            .unwrap_or(&body);
        return format!("HTTP {status}: {message}");
    }
    format!("HTTP {status}: {body}")
}
