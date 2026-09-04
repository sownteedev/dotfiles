use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fmt;
use std::str::FromStr;

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum ProviderKind {
    Google,
    Microsoft,
    CalDav,
}

impl ProviderKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Google => "google",
            Self::Microsoft => "microsoft",
            Self::CalDav => "caldav",
        }
    }
}

impl fmt::Display for ProviderKind {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

impl FromStr for ProviderKind {
    type Err = anyhow::Error;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "google" => Ok(Self::Google),
            "microsoft" => Ok(Self::Microsoft),
            "caldav" => Ok(Self::CalDav),
            other => anyhow::bail!("unsupported calendar provider: {other}"),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Account {
    pub id: String,
    pub provider: ProviderKind,
    pub display_name: String,
    pub email: String,
    pub config: Value,
    pub enabled: bool,
    pub needs_reauth: bool,
    pub last_error: String,
    pub last_sync_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Calendar {
    pub id: String,
    pub account_id: String,
    pub remote_id: String,
    pub name: String,
    pub description: String,
    pub color: String,
    pub time_zone: String,
    pub primary: bool,
    pub read_only: bool,
    pub visible: bool,
    #[serde(skip_serializing)]
    pub sync_token: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CalendarEvent {
    pub id: String,
    pub calendar_id: String,
    pub remote_id: String,
    pub uid: String,
    pub etag: String,
    pub title: String,
    pub description: String,
    pub location: String,
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub all_day: bool,
    pub status: String,
    pub recurrence: Vec<String>,
    #[serde(skip_serializing)]
    pub raw_payload: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EventDraft {
    pub title: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub location: String,
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    #[serde(default)]
    pub all_day: bool,
}

#[derive(Clone, Debug)]
pub struct RemoteCalendar {
    pub remote_id: String,
    pub name: String,
    pub description: String,
    pub color: String,
    pub time_zone: String,
    pub primary: bool,
    pub read_only: bool,
}

#[derive(Clone, Debug)]
pub enum EventChange {
    Upsert(Box<CalendarEvent>),
    Delete { remote_id: String },
}

#[derive(Clone, Debug)]
pub struct SyncBatch {
    pub changes: Vec<EventChange>,
    pub next_token: String,
    pub full_snapshot: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DaemonEvent {
    pub topic: String,
    pub kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub account_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub calendar_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AccountSyncReport {
    pub account_id: String,
    pub success: bool,
    pub calendars_synced: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncReport {
    pub accounts: Vec<AccountSyncReport>,
}

impl SyncReport {
    pub fn succeeded(&self) -> usize {
        self.accounts
            .iter()
            .filter(|account| account.success)
            .count()
    }

    pub fn failed(&self) -> usize {
        self.accounts.len().saturating_sub(self.succeeded())
    }
}

impl DaemonEvent {
    pub fn sync(kind: &str, account_id: &str, message: Option<String>) -> Self {
        Self {
            topic: "sync".to_string(),
            kind: kind.to_string(),
            account_id: Some(account_id.to_string()),
            calendar_id: None,
            message,
        }
    }

    pub fn changed(topic: &str, account_id: Option<&str>, calendar_id: Option<&str>) -> Self {
        Self {
            topic: topic.to_string(),
            kind: "changed".to_string(),
            account_id: account_id.map(str::to_string),
            calendar_id: calendar_id.map(str::to_string),
            message: None,
        }
    }
}
