use super::{
    CalendarProvider, OAUTH_CLIENT_SECRET_KEY, OAUTH_TOKEN_KEY, ProviderError, ProviderResult,
    SyncWindow, is_reauth_status, response_error,
};
use crate::keyring::Keyring;
use crate::model::{
    Account, Calendar, CalendarEvent, EventChange, EventDraft, EventPreferences, ProviderKind,
    RemoteCalendar, SyncBatch,
};
use crate::oauth::{OAuthToken, google as google_oauth};
use anyhow::{Context, anyhow};
use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, TimeZone, Utc};
use reqwest::{Client, StatusCode};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use url::Url;
use uuid::Uuid;

const CALENDAR_LIST_ENDPOINT: &str = "https://www.googleapis.com/calendar/v3/users/me/calendarList";
const CALENDAR_API_ROOT: &str = "https://www.googleapis.com/calendar/v3/";
const MASTER_SYNC_TOKEN_PREFIX: &str = "masters-reminders-v3:";

#[derive(Clone)]
pub struct GoogleProvider {
    http: Client,
    keyring: Keyring,
    token_gate: std::sync::Arc<tokio::sync::Mutex<()>>,
}

impl GoogleProvider {
    pub fn new(http: Client, keyring: Keyring) -> Self {
        Self {
            http,
            keyring,
            token_gate: Default::default(),
        }
    }

    pub(crate) async fn access_token(&self, account: &Account) -> ProviderResult<String> {
        let _guard = self.token_gate.lock().await;
        let client_id = account
            .config
            .get("clientId")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .ok_or_else(|| anyhow!("Google account is missing clientId"))?;
        let client_secret = self
            .keyring
            .get_text(&account.id, OAUTH_CLIENT_SECRET_KEY)
            .await?;
        let mut token = self
            .keyring
            .get_json::<OAuthToken>(&account.id, OAUTH_TOKEN_KEY)
            .await?
            .ok_or_else(|| ProviderError::Reauth("Google OAuth token is missing".to_string()))?;

        if token.needs_refresh() {
            token = google_oauth::refresh(&self.http, client_id, client_secret.as_deref(), &token)
                .await
                .map_err(classify_refresh_error)?;
            self.keyring
                .set_json(&account.id, OAUTH_TOKEN_KEY, &token)
                .await?;
        }
        Ok(token.access_token)
    }

    fn events_url(calendar_id: &str) -> ProviderResult<Url> {
        let mut url = Url::parse(CALENDAR_API_ROOT).map_err(anyhow::Error::from)?;
        url.path_segments_mut()
            .map_err(|_| anyhow!("Google Calendar API URL cannot hold path segments"))?
            .pop_if_empty()
            .extend(["calendars", calendar_id, "events"]);
        Ok(url)
    }

    fn event_url(calendar_id: &str, event_id: &str) -> ProviderResult<Url> {
        let mut url = Self::events_url(calendar_id)?;
        url.path_segments_mut()
            .map_err(|_| anyhow!("Google Calendar API URL cannot hold path segments"))?
            .push(event_id);
        Ok(url)
    }
}

#[async_trait]
impl CalendarProvider for GoogleProvider {
    fn kind(&self) -> ProviderKind {
        ProviderKind::Google
    }

    async fn list_calendars(&self, account: &Account) -> ProviderResult<Vec<RemoteCalendar>> {
        let token = self.access_token(account).await?;
        let mut page_token = String::new();
        let mut calendars = Vec::new();
        loop {
            let mut request = self
                .http
                .get(CALENDAR_LIST_ENDPOINT)
                .bearer_auth(&token)
                .query(&[("maxResults", "250"), ("showHidden", "true")]);
            if !page_token.is_empty() {
                request = request.query(&[("pageToken", page_token.as_str())]);
            }
            let response = request.send().await?;
            if is_reauth_status(response.status()) {
                return Err(ProviderError::Reauth(response_error(response).await));
            }
            if !response.status().is_success() {
                return Err(anyhow!(response_error(response).await).into());
            }
            let page = response.json::<GoogleCalendarPage>().await?;
            calendars.extend(page.items.into_iter().map(|calendar| {
                let default_reminder_minutes = calendar
                    .default_reminders
                    .iter()
                    .filter(|reminder| reminder.method == "popup" && reminder.minutes >= 0)
                    .map(|reminder| reminder.minutes)
                    .min();
                RemoteCalendar {
                    remote_id: calendar.id,
                    name: calendar.summary,
                    description: calendar.description,
                    color: calendar.background_color,
                    time_zone: calendar.time_zone,
                    default_reminder_minutes,
                    primary: calendar.primary,
                    read_only: !matches!(calendar.access_role.as_str(), "owner" | "writer"),
                }
            }));
            page_token = page.next_page_token;
            if page_token.is_empty() {
                break;
            }
        }
        Ok(calendars)
    }

    async fn sync_calendar(
        &self,
        account: &Account,
        calendar: &Calendar,
        window: SyncWindow,
    ) -> ProviderResult<SyncBatch> {
        let token = self.access_token(account).await?;
        // Older builds stored a cursor produced with `singleEvents=true`, which
        // represents recurring occurrences rather than their series masters.
        // A prefixed cursor makes the representation change explicit and forces
        // one clean full snapshot for existing installations.
        let sync_token = calendar.sync_token.strip_prefix(MASTER_SYNC_TOKEN_PREFIX);
        let incremental = sync_token.is_some();
        let mut page_token = String::new();
        let mut next_sync_token = String::new();
        let mut changes = Vec::new();

        loop {
            let mut request = self
                .http
                .get(Self::events_url(&calendar.remote_id)?)
                .bearer_auth(&token)
                .query(&[
                    ("maxResults", "2500"),
                    ("showDeleted", "true"),
                    ("singleEvents", "false"),
                ]);
            if incremental {
                request = request.query(&[("syncToken", sync_token.unwrap_or_default())]);
            } else {
                let start = window.start.to_rfc3339();
                let end = window.end.to_rfc3339();
                request = request.query(&[("timeMin", start.as_str()), ("timeMax", end.as_str())]);
            }
            if !page_token.is_empty() {
                request = request.query(&[("pageToken", page_token.as_str())]);
            }

            let response = request.send().await?;
            if response.status() == StatusCode::GONE {
                return Err(ProviderError::CursorExpired(
                    "Google invalidated the sync token".to_string(),
                ));
            }
            if is_reauth_status(response.status()) {
                return Err(ProviderError::Reauth(response_error(response).await));
            }
            if !response.status().is_success() {
                return Err(anyhow!(response_error(response).await).into());
            }
            let page = response.json::<GoogleEventPage>().await?;
            for event in page.items {
                if event.status == "cancelled" {
                    changes.push(EventChange::Delete {
                        remote_id: event.id,
                    });
                    continue;
                }
                changes.push(EventChange::Upsert(Box::new(
                    event.into_model_with_defaults(&calendar.id, &page.default_reminders)?,
                )));
            }
            page_token = page.next_page_token;
            if !page.next_sync_token.is_empty() {
                next_sync_token = format!("{MASTER_SYNC_TOKEN_PREFIX}{}", page.next_sync_token);
            }
            if page_token.is_empty() {
                break;
            }
        }

        Ok(SyncBatch {
            changes,
            next_token: next_sync_token,
            full_snapshot: !incremental,
        })
    }

    async fn create_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        draft: &EventDraft,
    ) -> ProviderResult<CalendarEvent> {
        let token = self.access_token(account).await?;
        let response = self
            .http
            .post(Self::events_url(&calendar.remote_id)?)
            .bearer_auth(&token)
            .json(&GoogleEventPayload::from(draft))
            .send()
            .await?;
        if is_reauth_status(response.status()) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() {
            return Err(anyhow!(response_error(response).await).into());
        }
        response
            .json::<GoogleEvent>()
            .await?
            .into_model(&calendar.id)
            .map(|mut event| {
                event.preferences = draft.preferences.clone();
                if event.recurrence.is_empty() && !draft.recurrence.is_empty() {
                    event.recurrence = draft.recurrence.clone();
                }
                event
            })
    }

    async fn update_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        event: &CalendarEvent,
        draft: &EventDraft,
    ) -> ProviderResult<CalendarEvent> {
        let token = self.access_token(account).await?;
        let response = self
            .http
            .patch(Self::event_url(&calendar.remote_id, &event.remote_id)?)
            .bearer_auth(&token)
            .json(&GoogleEventPayload::from(draft))
            .send()
            .await?;
        if is_reauth_status(response.status()) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() {
            return Err(anyhow!(response_error(response).await).into());
        }
        let mut updated = response
            .json::<GoogleEvent>()
            .await?
            .into_model(&calendar.id)?;
        updated.id = event.id.clone();
        updated.preferences = draft.preferences.clone();
        if updated.recurrence.is_empty() && !draft.recurrence.is_empty() {
            updated.recurrence = draft.recurrence.clone();
        }
        Ok(updated)
    }

    async fn delete_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        event: &CalendarEvent,
    ) -> ProviderResult<()> {
        let token = self.access_token(account).await?;
        let response = self
            .http
            .delete(Self::event_url(&calendar.remote_id, &event.remote_id)?)
            .bearer_auth(&token)
            .send()
            .await?;
        if is_reauth_status(response.status()) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() {
            return Err(anyhow!(response_error(response).await).into());
        }
        Ok(())
    }
}

#[derive(Debug, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct GoogleReminders {
    #[serde(default)]
    use_default: bool,
    #[serde(default)]
    #[serde(skip_serializing_if = "Vec::is_empty")]
    overrides: Vec<GoogleReminder>,
}

#[derive(Debug, Deserialize, Serialize)]
struct GoogleReminder {
    method: String,
    minutes: i64,
}

impl GoogleReminders {
    fn minutes(&self, defaults: &[GoogleReminder]) -> Option<i64> {
        let reminders = if self.use_default { defaults } else { &self.overrides };
        // A single notification reminder; email-only alarms are not popup alarms.
        reminders.iter().filter(|r| r.method == "popup" && r.minutes >= 0)
            .map(|r| r.minutes).min()
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct GoogleEventPayload<'a> {
    reminders: GoogleReminders,
    summary: &'a str,
    description: &'a str,
    location: &'a str,
    start: GoogleEventTimePayload,
    end: GoogleEventTimePayload,
    #[serde(skip_serializing_if = "Option::is_none")]
    recurrence: Option<&'a [String]>,
    #[serde(skip_serializing_if = "Option::is_none")]
    transparency: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    visibility: Option<&'static str>,
}

impl<'a> From<&'a EventDraft> for GoogleEventPayload<'a> {
    fn from(draft: &'a EventDraft) -> Self {
        let transparency = if draft.preferences.availability == "free" {
            Some("transparent")
        } else {
            Some("opaque")
        };
        let visibility = match draft.preferences.visibility.as_str() {
            "public" => Some("public"),
            "private" => Some("private"),
            _ => Some("default"),
        };
        Self {
            reminders: GoogleReminders {
                use_default: draft.preferences.use_default_reminder,
                overrides: draft.preferences.reminder_minutes
                    .filter(|_| !draft.preferences.use_default_reminder)
                    .map(|minutes| GoogleReminder { method: "popup".into(), minutes }).into_iter().collect(),
            },
            summary: &draft.title,
            description: &draft.description,
            location: &draft.location,
            start: GoogleEventTimePayload::new(draft.start, draft.all_day),
            end: GoogleEventTimePayload::new(draft.end, draft.all_day),
            recurrence: (!draft.recurrence.is_empty()).then_some(draft.recurrence.as_slice()),
            transparency,
            visibility,
        }
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct GoogleEventTimePayload {
    #[serde(skip_serializing_if = "Option::is_none")]
    date: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    date_time: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    time_zone: Option<&'static str>,
}

impl GoogleEventTimePayload {
    fn new(value: DateTime<Utc>, all_day: bool) -> Self {
        if all_day {
            Self {
                date: Some(value.date_naive().format("%Y-%m-%d").to_string()),
                date_time: None,
                time_zone: None,
            }
        } else {
            Self {
                date: None,
                date_time: Some(value.to_rfc3339()),
                time_zone: Some("UTC"),
            }
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GoogleCalendarPage {
    #[serde(default)]
    items: Vec<GoogleCalendar>,
    #[serde(default)]
    next_page_token: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GoogleCalendar {
    id: String,
    #[serde(default)]
    summary: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    background_color: String,
    #[serde(default)]
    time_zone: String,
    #[serde(default)]
    primary: bool,
    #[serde(default)]
    access_role: String,
    #[serde(default)]
    default_reminders: Vec<GoogleReminder>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GoogleEventPage {
    #[serde(default)]
    default_reminders: Vec<GoogleReminder>,
    #[serde(default)]
    items: Vec<GoogleEvent>,
    #[serde(default)]
    next_page_token: String,
    #[serde(default)]
    next_sync_token: String,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GoogleDateTime {
    date: Option<String>,
    date_time: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GoogleEvent {
    #[serde(default)]
    reminders: GoogleReminders,
    id: String,
    #[serde(default)]
    i_cal_uid: String,
    #[serde(default)]
    etag: String,
    #[serde(default)]
    summary: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    location: String,
    #[serde(default)]
    status: String,
    #[serde(default)]
    start: GoogleDateTime,
    #[serde(default)]
    end: GoogleDateTime,
    #[serde(default)]
    recurrence: Vec<String>,
    #[serde(default)]
    transparency: Option<String>,
    #[serde(default)]
    visibility: Option<String>,
    created: Option<String>,
    updated: Option<String>,
}

impl GoogleEvent {
    fn into_model(self, calendar_id: &str) -> ProviderResult<CalendarEvent> {
        self.into_model_with_defaults(calendar_id, &[])
    }

    fn into_model_with_defaults(self, calendar_id: &str, defaults: &[GoogleReminder]) -> ProviderResult<CalendarEvent> {
        let reminder_minutes = self.reminders.minutes(defaults);
        let all_day = self.start.date.is_some();
        let start = parse_google_time(&self.start)
            .with_context(|| format!("Google event {} has no valid start", self.id))?;
        let end = parse_google_time(&self.end).unwrap_or_else(|_| {
            start
                + if all_day {
                    chrono::Duration::days(1)
                } else {
                    chrono::Duration::hours(1)
                }
        });
        let now = Utc::now();
        let created = parse_optional_rfc3339(self.created.as_deref()).unwrap_or(now);
        let updated = parse_optional_rfc3339(self.updated.as_deref()).unwrap_or(now);
        let raw_payload = serde_json::to_string(&serde_json::json!({
            "provider": "google",
            "remoteId": self.id.clone(),
        }))?;
        Ok(CalendarEvent {
            id: Uuid::new_v4().to_string(),
            calendar_id: calendar_id.to_string(),
            remote_id: self.id,
            uid: self.i_cal_uid,
            etag: self.etag,
            title: self.summary,
            description: self.description,
            location: self.location,
            start,
            end,
            all_day,
            status: if self.status.is_empty() {
                "confirmed".to_string()
            } else {
                self.status
            },
            recurrence: self.recurrence,

            preferences: EventPreferences {
                reminder_minutes,
                use_default_reminder: self.reminders.use_default,
                availability: if self.transparency.as_deref() == Some("transparent") {
                    "free".to_string()
                } else {
                    "busy".to_string()
                },
                visibility: match self.visibility.as_deref() {
                    Some("public") => "public".to_string(),
                    Some("private") => "private".to_string(),
                    _ => "default".to_string(),
                },
            },
            raw_payload,
            created_at: created,
            updated_at: updated,
        })
    }
}

fn parse_google_time(value: &GoogleDateTime) -> anyhow::Result<DateTime<Utc>> {
    if let Some(date_time) = value.date_time.as_deref() {
        return Ok(DateTime::parse_from_rfc3339(date_time)?.with_timezone(&Utc));
    }
    if let Some(date) = value.date.as_deref() {
        let date = NaiveDate::parse_from_str(date, "%Y-%m-%d")?;
        return Ok(Utc.from_utc_datetime(&date.and_hms_opt(0, 0, 0).unwrap()));
    }
    Err(anyhow!("missing date and dateTime"))
}

fn parse_optional_rfc3339(value: Option<&str>) -> Option<DateTime<Utc>> {
    value
        .and_then(|value| DateTime::parse_from_rfc3339(value).ok())
        .map(|value| value.with_timezone(&Utc))
}

fn classify_refresh_error(error: anyhow::Error) -> ProviderError {
    let text = error.to_string();
    if text.contains("invalid_grant") || text.contains("401") || text.contains("unauthorized") {
        ProviderError::Reauth(text)
    } else {
        ProviderError::Other(error)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn single_cloud_reminder_round_trips_and_clears() {
        for minutes in [Some(0), Some(15), Some(1440), None] {
            for all_day in [false, true] {
                let draft: EventDraft = serde_json::from_value(serde_json::json!({
                    "title": "Monthly test", "start": "2026-10-04T00:00:00Z",
                    "end": "2026-10-05T00:00:00Z", "allDay": all_day,
                    "recurrence": ["RRULE:FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=4"],
                    "reminderMinutes": minutes
                })).unwrap();
                let mut value = serde_json::to_value(GoogleEventPayload::from(&draft)).unwrap();
                assert_eq!(value["reminders"]["useDefault"], false);
                assert_eq!(value["reminders"]["overrides"].as_array().map_or(0, Vec::len), usize::from(minutes.is_some()));
                assert_eq!(value["recurrence"][0], draft.recurrence[0]);
                value["id"] = "test".into();
                let event: GoogleEvent = serde_json::from_value(value).unwrap();
                assert_eq!(event.into_model("calendar").unwrap().preferences.reminder_minutes, minutes);
            }
        }
    }

    #[test]
    fn google_default_and_multiple_reminders_choose_one_popup() {
        let reminders: GoogleReminders = serde_json::from_value(serde_json::json!({
            "useDefault": true
        })).unwrap();
        let defaults = vec![
            GoogleReminder { method: "email".into(), minutes: 5 },
            GoogleReminder { method: "popup".into(), minutes: 30 },
            GoogleReminder { method: "popup".into(), minutes: 10 },
        ];
        assert_eq!(reminders.minutes(&defaults), Some(10));
        let disabled = GoogleReminders::default();
        assert_eq!(disabled.minutes(&defaults), None);
    }

    #[test]
    fn parses_all_day_boundary() {
        let value = GoogleDateTime {
            date: Some("2026-09-02".to_string()),
            date_time: None,
        };
        assert_eq!(
            parse_google_time(&value).expect("parse date").to_rfc3339(),
            "2026-09-02T00:00:00+00:00"
        );
    }

    #[test]
    fn encodes_calendar_ids_without_double_slashes() {
        assert_eq!(
            GoogleProvider::events_url("user@example.com")
                .expect("event URL")
                .as_str(),
            "https://www.googleapis.com/calendar/v3/calendars/user@example.com/events"
        );
    }
}
