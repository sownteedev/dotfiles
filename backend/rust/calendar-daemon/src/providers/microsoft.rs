use super::{
    CalendarProvider, OAUTH_TOKEN_KEY, ProviderError, ProviderResult, SyncWindow, is_reauth_status,
    response_error,
};
use crate::keyring::Keyring;
use crate::model::{
    Account, Calendar, CalendarEvent, EventChange, EventDraft, ProviderKind, RemoteCalendar,
    SyncBatch,
};
use crate::oauth::{OAuthToken, microsoft as microsoft_oauth};
use anyhow::{Context, anyhow};
use async_trait::async_trait;
use chrono::{DateTime, NaiveDateTime, TimeZone, Utc};
use reqwest::{Client, StatusCode};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use url::Url;
use uuid::Uuid;

const GRAPH_ROOT: &str = "https://graph.microsoft.com/v1.0/";

#[derive(Clone)]
pub struct MicrosoftProvider {
    http: Client,
    keyring: Keyring,
}

impl MicrosoftProvider {
    pub fn new(http: Client, keyring: Keyring) -> Self {
        Self { http, keyring }
    }

    async fn access_token(&self, account: &Account) -> ProviderResult<String> {
        let client_id = account
            .config
            .get("clientId")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .ok_or_else(|| anyhow!("Microsoft account is missing clientId"))?;
        let tenant = account
            .config
            .get("tenant")
            .and_then(Value::as_str)
            .unwrap_or("common");
        let mut token = self
            .keyring
            .get_json::<OAuthToken>(&account.id, OAUTH_TOKEN_KEY)
            .await?
            .ok_or_else(|| ProviderError::Reauth("Microsoft OAuth token is missing".to_string()))?;
        if token.needs_refresh() {
            token = microsoft_oauth::refresh(&self.http, client_id, tenant, &token)
                .await
                .map_err(classify_refresh_error)?;
            self.keyring
                .set_json(&account.id, OAUTH_TOKEN_KEY, &token)
                .await?;
        }
        Ok(token.access_token)
    }

    fn calendar_view_url(calendar: &Calendar) -> ProviderResult<Url> {
        let mut url = Url::parse(GRAPH_ROOT).map_err(anyhow::Error::from)?;
        let mut segments = url
            .path_segments_mut()
            .map_err(|_| anyhow!("Microsoft Graph URL cannot hold path segments"))?;
        segments.pop_if_empty();
        if calendar.primary {
            segments.extend(["me", "calendarView", "delta"]);
        } else {
            segments.extend(["me", "calendars", &calendar.remote_id, "calendarView"]);
        }
        drop(segments);
        Ok(url)
    }

    fn calendar_events_url(calendar: &Calendar) -> ProviderResult<Url> {
        let mut url = Url::parse(GRAPH_ROOT).map_err(anyhow::Error::from)?;
        url.path_segments_mut()
            .map_err(|_| anyhow!("Microsoft Graph URL cannot hold path segments"))?
            .pop_if_empty()
            .extend(["me", "calendars", &calendar.remote_id, "events"]);
        Ok(url)
    }

    fn event_url(event_id: &str) -> ProviderResult<Url> {
        let mut url = Url::parse(GRAPH_ROOT).map_err(anyhow::Error::from)?;
        url.path_segments_mut()
            .map_err(|_| anyhow!("Microsoft Graph URL cannot hold path segments"))?
            .pop_if_empty()
            .extend(["me", "events", event_id]);
        Ok(url)
    }
}

#[async_trait]
impl CalendarProvider for MicrosoftProvider {
    fn kind(&self) -> ProviderKind {
        ProviderKind::Microsoft
    }

    async fn list_calendars(&self, account: &Account) -> ProviderResult<Vec<RemoteCalendar>> {
        let token = self.access_token(account).await?;
        let mut next = Some(format!("{GRAPH_ROOT}me/calendars?$top=100"));
        let mut calendars = Vec::new();
        while let Some(url) = next.take() {
            let response = self.http.get(url).bearer_auth(&token).send().await?;
            if is_reauth_status(response.status()) {
                return Err(ProviderError::Reauth(response_error(response).await));
            }
            if !response.status().is_success() {
                return Err(anyhow!(response_error(response).await).into());
            }
            let page = response.json::<GraphPage<MicrosoftCalendar>>().await?;
            calendars.extend(page.value.into_iter().map(|calendar| RemoteCalendar {
                remote_id: calendar.id,
                name: calendar.name,
                description: String::new(),
                color: microsoft_color(&calendar.color),
                time_zone: String::new(),
                primary: calendar.is_default_calendar,
                read_only: !calendar.can_edit,
            }));
            next = page.next_link;
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
        let supports_delta = calendar.primary;
        let incremental = supports_delta && !calendar.sync_token.is_empty();
        let mut next = if incremental {
            Some(calendar.sync_token.clone())
        } else {
            let mut url = Self::calendar_view_url(calendar)?;
            url.query_pairs_mut()
                .append_pair("startDateTime", &window.start.to_rfc3339())
                .append_pair("endDateTime", &window.end.to_rfc3339());
            Some(url.into())
        };
        let mut next_token = String::new();
        let mut changes = Vec::new();

        while let Some(url) = next.take() {
            let response = self
                .http
                .get(url)
                .bearer_auth(&token)
                .header("Prefer", "outlook.timezone=\"UTC\", odata.maxpagesize=1000")
                .send()
                .await?;
            if incremental && response.status() == StatusCode::GONE {
                return Err(ProviderError::CursorExpired(
                    "Microsoft invalidated the delta link".to_string(),
                ));
            }
            if is_reauth_status(response.status()) {
                return Err(ProviderError::Reauth(response_error(response).await));
            }
            if !response.status().is_success() {
                return Err(anyhow!(response_error(response).await).into());
            }
            let page = response.json::<GraphPage<MicrosoftEvent>>().await?;
            for event in page.value {
                if event.removed.is_some() || event.is_cancelled {
                    changes.push(EventChange::Delete {
                        remote_id: event.id,
                    });
                    continue;
                }
                changes.push(EventChange::Upsert(Box::new(
                    event.into_model(&calendar.id)?,
                )));
            }
            next = page.next_link;
            if supports_delta && let Some(delta_link) = page.delta_link {
                next_token = delta_link;
            }
        }

        Ok(SyncBatch {
            changes,
            next_token,
            full_snapshot: !supports_delta || !incremental,
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
            .post(Self::calendar_events_url(calendar)?)
            .bearer_auth(&token)
            .header("Prefer", "outlook.timezone=\"UTC\"")
            .json(&MicrosoftEventPayload::from(draft))
            .send()
            .await?;
        if is_reauth_status(response.status()) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() {
            return Err(anyhow!(response_error(response).await).into());
        }
        let mut created = response
            .json::<MicrosoftEvent>()
            .await?
            .into_model(&calendar.id)?;
        created.description = draft.description.clone();
        Ok(created)
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
            .patch(Self::event_url(&event.remote_id)?)
            .bearer_auth(&token)
            .header("Prefer", "outlook.timezone=\"UTC\"")
            .json(&MicrosoftEventPayload::from(draft))
            .send()
            .await?;
        if is_reauth_status(response.status()) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() {
            return Err(anyhow!(response_error(response).await).into());
        }
        let mut updated = response
            .json::<MicrosoftEvent>()
            .await?
            .into_model(&calendar.id)?;
        updated.id = event.id.clone();
        updated.description = draft.description.clone();
        Ok(updated)
    }

    async fn delete_event(
        &self,
        account: &Account,
        _calendar: &Calendar,
        event: &CalendarEvent,
    ) -> ProviderResult<()> {
        let token = self.access_token(account).await?;
        let response = self
            .http
            .delete(Self::event_url(&event.remote_id)?)
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

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftEventPayload<'a> {
    subject: &'a str,
    body: MicrosoftBodyPayload<'a>,
    start: MicrosoftDateTimePayload,
    end: MicrosoftDateTimePayload,
    location: MicrosoftLocationPayload<'a>,
    is_all_day: bool,
}

impl<'a> From<&'a EventDraft> for MicrosoftEventPayload<'a> {
    fn from(draft: &'a EventDraft) -> Self {
        Self {
            subject: &draft.title,
            body: MicrosoftBodyPayload {
                content_type: "text",
                content: &draft.description,
            },
            start: MicrosoftDateTimePayload::new(draft.start),
            end: MicrosoftDateTimePayload::new(draft.end),
            location: MicrosoftLocationPayload {
                display_name: &draft.location,
            },
            is_all_day: draft.all_day,
        }
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftBodyPayload<'a> {
    content_type: &'static str,
    content: &'a str,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftDateTimePayload {
    date_time: String,
    time_zone: &'static str,
}

impl MicrosoftDateTimePayload {
    fn new(value: DateTime<Utc>) -> Self {
        Self {
            date_time: value.format("%Y-%m-%dT%H:%M:%S").to_string(),
            time_zone: "UTC",
        }
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftLocationPayload<'a> {
    display_name: &'a str,
}

#[derive(Debug, Deserialize)]
struct GraphPage<T> {
    value: Vec<T>,
    #[serde(rename = "@odata.nextLink")]
    next_link: Option<String>,
    #[serde(rename = "@odata.deltaLink")]
    delta_link: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftCalendar {
    id: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    color: String,
    #[serde(default)]
    can_edit: bool,
    #[serde(default)]
    is_default_calendar: bool,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftDateTime {
    #[serde(default)]
    date_time: String,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftLocation {
    #[serde(default)]
    display_name: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftEvent {
    id: String,
    #[serde(rename = "@odata.etag", default)]
    etag: String,
    #[serde(rename = "@removed")]
    removed: Option<Value>,
    #[serde(default)]
    i_cal_uid: String,
    #[serde(default)]
    subject: String,
    #[serde(default)]
    body_preview: String,
    #[serde(default)]
    location: MicrosoftLocation,
    #[serde(default)]
    start: MicrosoftDateTime,
    #[serde(default)]
    end: MicrosoftDateTime,
    #[serde(default)]
    is_all_day: bool,
    #[serde(default)]
    is_cancelled: bool,
    recurrence: Option<Value>,
    created_date_time: Option<String>,
    last_modified_date_time: Option<String>,
}

impl MicrosoftEvent {
    fn into_model(self, calendar_id: &str) -> ProviderResult<CalendarEvent> {
        let start = parse_graph_time(&self.start.date_time)
            .with_context(|| format!("Microsoft event {} has an invalid start", self.id))?;
        let end = parse_graph_time(&self.end.date_time).unwrap_or_else(|_| {
            start
                + if self.is_all_day {
                    chrono::Duration::days(1)
                } else {
                    chrono::Duration::hours(1)
                }
        });
        let now = Utc::now();
        let created =
            parse_graph_time(self.created_date_time.as_deref().unwrap_or_default()).unwrap_or(now);
        let updated = parse_graph_time(self.last_modified_date_time.as_deref().unwrap_or_default())
            .unwrap_or(now);
        let recurrence = self
            .recurrence
            .map(|value| vec![value.to_string()])
            .unwrap_or_default();
        Ok(CalendarEvent {
            id: Uuid::new_v4().to_string(),
            calendar_id: calendar_id.to_string(),
            remote_id: self.id,
            uid: self.i_cal_uid,
            etag: self.etag,
            title: self.subject,
            description: self.body_preview,
            location: self.location.display_name,
            start,
            end,
            all_day: self.is_all_day,
            status: "confirmed".to_string(),
            recurrence,
            raw_payload: String::new(),
            created_at: created,
            updated_at: updated,
        })
    }
}

fn parse_graph_time(value: &str) -> anyhow::Result<DateTime<Utc>> {
    if value.is_empty() {
        return Err(anyhow!("empty dateTime"));
    }
    if let Ok(date_time) = DateTime::parse_from_rfc3339(value) {
        return Ok(date_time.with_timezone(&Utc));
    }
    let naive = NaiveDateTime::parse_from_str(value, "%Y-%m-%dT%H:%M:%S%.f")?;
    Ok(Utc.from_utc_datetime(&naive))
}

fn microsoft_color(value: &str) -> String {
    match value {
        "lightBlue" => "#64b5f6",
        "lightGreen" => "#81c784",
        "lightOrange" => "#ffb74d",
        "lightGray" => "#b0bec5",
        "lightYellow" => "#fff176",
        "lightTeal" => "#4db6ac",
        "lightPink" => "#f48fb1",
        "lightBrown" => "#bcaaa4",
        "lightRed" => "#e57373",
        "maxColor" | "auto" | "" => "#7c8cff",
        _ => "#7c8cff",
    }
    .to_string()
}

fn classify_refresh_error(error: anyhow::Error) -> ProviderError {
    let text = error.to_string();
    if text.contains("invalid_grant")
        || text.contains("AADSTS")
        || text.contains("401")
        || text.contains("unauthorized")
    {
        ProviderError::Reauth(text)
    } else {
        ProviderError::Other(error)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn calendar(primary: bool) -> Calendar {
        let now = Utc::now();
        Calendar {
            id: "local-calendar".to_string(),
            account_id: "microsoft:test".to_string(),
            remote_id: "remote-calendar".to_string(),
            name: "Calendar".to_string(),
            description: String::new(),
            color: String::new(),
            time_zone: "UTC".to_string(),
            primary,
            read_only: false,
            visible: true,
            sync_token: String::new(),
            created_at: now,
            updated_at: now,
        }
    }

    #[test]
    fn parses_graph_utc_without_suffix() {
        assert_eq!(
            parse_graph_time("2026-09-02T08:30:00.0000000")
                .expect("parse graph time")
                .to_rfc3339(),
            "2026-09-02T08:30:00+00:00"
        );
    }

    #[test]
    fn uses_delta_only_for_the_default_calendar() {
        assert_eq!(
            MicrosoftProvider::calendar_view_url(&calendar(true))
                .expect("default calendar URL")
                .path(),
            "/v1.0/me/calendarView/delta"
        );
        assert_eq!(
            MicrosoftProvider::calendar_view_url(&calendar(false))
                .expect("secondary calendar URL")
                .path(),
            "/v1.0/me/calendars/remote-calendar/calendarView"
        );
    }
}
