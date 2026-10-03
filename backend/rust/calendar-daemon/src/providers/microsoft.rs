use super::{
    CalendarProvider, OAUTH_TOKEN_KEY, ProviderError, ProviderResult, SyncWindow, is_reauth_status,
    response_error,
};
use crate::keyring::Keyring;
use crate::model::{
    Account, Calendar, CalendarEvent, EventChange, EventDraft, EventPreferences, ProviderKind,
    RemoteCalendar, SyncBatch,
};
use crate::oauth::{OAuthToken, microsoft as microsoft_oauth};
use anyhow::{Context, anyhow};
use async_trait::async_trait;
use chrono::{DateTime, Datelike, LocalResult, NaiveDateTime, TimeZone, Utc};
use chrono_tz::Tz;
use reqwest::Client;
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
                default_reminder_minutes: None,
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
        _window: SyncWindow,
    ) -> ProviderResult<SyncBatch> {
        let token = self.access_token(account).await?;
        // `/calendarView` expands a recurring series into occurrence events.  That
        // loses the series master's recurrence rule and makes the local database
        // show "Does not repeat" when the occurrence is opened in the editor.
        // Fetch the calendar's event collection instead so the series master is
        // retained.  Microsoft sync cursors from the old calendarView endpoint
        // are intentionally ignored; the full snapshot also cleans stale
        // occurrence rows left by older versions.
        let mut url = Self::calendar_events_url(calendar)?;
        url.query_pairs_mut().append_pair("$top", "1000");
        let mut next = Some(url.into());
        let next_token = String::new();
        let mut changes = Vec::new();

        while let Some(url) = next.take() {
            let response = self
                .http
                .get(url)
                .bearer_auth(&token)
                .header("Prefer", "outlook.timezone=\"UTC\", odata.maxpagesize=1000")
                .send()
                .await?;
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
        }

        Ok(SyncBatch {
            changes,
            next_token,
            full_snapshot: true,
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
        created.preferences = draft.preferences.clone();
        if created.recurrence.is_empty() && !draft.recurrence.is_empty() {
            created.recurrence = draft.recurrence.clone();
        }
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
        updated.preferences = draft.preferences.clone();
        if updated.recurrence.is_empty() && !draft.recurrence.is_empty() {
            updated.recurrence = draft.recurrence.clone();
        }
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
    #[serde(skip_serializing_if = "Option::is_none")]
    recurrence: Option<Value>,
    show_as: &'static str,
    sensitivity: &'static str,
    is_reminder_on: bool,
    reminder_minutes_before_start: i64,
}

impl<'a> From<&'a EventDraft> for MicrosoftEventPayload<'a> {
    fn from(draft: &'a EventDraft) -> Self {
        let zone = std::env::var("TZ")
            .ok()
            .and_then(|name| name.trim_start_matches(':').parse::<Tz>().ok())
            .or_else(|| iana_time_zone::get_timezone().ok()?.parse::<Tz>().ok())
            .unwrap_or(chrono_tz::UTC);
        Self::in_time_zone(draft, zone)
    }
}

impl<'a> MicrosoftEventPayload<'a> {
    fn in_time_zone(draft: &'a EventDraft, zone: Tz) -> Self {
        // The editor sends timed events as UTC instants, but recurrence days
        // refer to the editor's local calendar. All-day dates are encoded as
        // UTC midnight and must not be converted to the previous/next day.
        let zone = if draft.all_day { chrono_tz::UTC } else { zone };
        let show_as = if draft.preferences.availability == "free" {
            "free"
        } else {
            "busy"
        };
        let sensitivity = if draft.preferences.visibility == "private" {
            "private"
        } else {
            "normal"
        };
        Self {
            subject: &draft.title,
            body: MicrosoftBodyPayload {
                content_type: "text",
                content: &draft.description,
            },
            start: MicrosoftDateTimePayload::new(draft.start, zone),
            end: MicrosoftDateTimePayload::new(draft.end, zone),
            location: MicrosoftLocationPayload {
                display_name: &draft.location,
            },
            is_all_day: draft.all_day,
            recurrence: microsoft_recurrence(draft, zone),
            show_as,
            sensitivity,
            is_reminder_on: draft.preferences.reminder_minutes.is_some(),
            reminder_minutes_before_start: draft.preferences.reminder_minutes.unwrap_or(0),
        }
    }
}

fn microsoft_recurrence(draft: &EventDraft, zone: Tz) -> Option<Value> {
    let start = draft.start.with_timezone(&zone);
    let rule = draft.recurrence.first()?.trim();
    let rule = rule.strip_prefix("RRULE:").unwrap_or(rule);
    let mut frequency = None;
    let mut interval = 1_i64;
    let mut count = None;
    let mut until = None;
    let mut by_day = Vec::new();
    let mut day_of_month = None;

    for part in rule.split(';') {
        let (key, value) = part.split_once('=')?;
        match key {
            "FREQ" => frequency = Some(value.to_ascii_uppercase()),
            "INTERVAL" => interval = value.parse().ok()?,
            "COUNT" => count = Some(value.parse::<u64>().ok()?),
            "UNTIL" => {
                until = Some(
                    if value.len() >= 8 && value.as_bytes()[0..8].iter().all(u8::is_ascii_digit) {
                        format!("{}-{}-{}", &value[0..4], &value[4..6], &value[6..8])
                    } else {
                        value.chars().take(10).collect()
                    },
                );
            }
            "BYDAY" => {
                by_day = value
                    .split(',')
                    .filter_map(|day| match day.trim().to_ascii_uppercase().as_str() {
                        "MO" => Some("monday"),
                        "TU" => Some("tuesday"),
                        "WE" => Some("wednesday"),
                        "TH" => Some("thursday"),
                        "FR" => Some("friday"),
                        "SA" => Some("saturday"),
                        "SU" => Some("sunday"),
                        _ => None,
                    })
                    .collect();
            }
            "BYMONTHDAY" => day_of_month = value.parse::<u64>().ok(),
            _ => {}
        }
    }

    let frequency = frequency?;
    let pattern_type = match frequency.as_str() {
        "DAILY" => "daily",
        "WEEKLY" => "weekly",
        "MONTHLY" => "absoluteMonthly",
        "YEARLY" => "absoluteYearly",
        _ => return None,
    };
    let mut pattern = serde_json::Map::new();
    pattern.insert("type".to_string(), Value::String(pattern_type.to_string()));
    pattern.insert("interval".to_string(), Value::from(interval.max(1)));
    if pattern_type == "weekly" {
        if by_day.is_empty() {
            let day = match start.weekday() {
                chrono::Weekday::Mon => "monday",
                chrono::Weekday::Tue => "tuesday",
                chrono::Weekday::Wed => "wednesday",
                chrono::Weekday::Thu => "thursday",
                chrono::Weekday::Fri => "friday",
                chrono::Weekday::Sat => "saturday",
                chrono::Weekday::Sun => "sunday",
            };
            by_day.push(day);
        }
        pattern.insert("daysOfWeek".to_string(), Value::from(by_day));
        pattern.insert(
            "firstDayOfWeek".to_string(),
            Value::String("monday".to_string()),
        );
    }
    if matches!(pattern_type, "absoluteMonthly" | "absoluteYearly") {
        let day = day_of_month.unwrap_or_else(|| start.day() as u64);
        pattern.insert("dayOfMonth".to_string(), Value::from(day.clamp(1, 31)));
        if pattern_type == "absoluteYearly" {
            pattern.insert("month".to_string(), Value::from(start.month()));
        }
    }

    let mut range = serde_json::Map::new();
    range.insert(
        "type".to_string(),
        Value::String(
            if let Some(_) = count {
                "numbered"
            } else if until.is_some() {
                "endDate"
            } else {
                "noEnd"
            }
            .to_string(),
        ),
    );
    range.insert(
        "startDate".to_string(),
        Value::String(start.format("%Y-%m-%d").to_string()),
    );
    range.insert(
        "recurrenceTimeZone".to_string(),
        Value::String(graph_time_zone_name(zone)),
    );
    if let Some(number) = count {
        range.insert("numberOfOccurrences".to_string(), Value::from(number));
    }
    if let Some(end_date) = until {
        range.insert("endDate".to_string(), Value::String(end_date));
    }
    Some(Value::Object(
        [
            ("pattern".to_string(), Value::Object(pattern)),
            ("range".to_string(), Value::Object(range)),
        ]
        .into_iter()
        .collect(),
    ))
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
    time_zone: String,
}

impl MicrosoftDateTimePayload {
    fn new(value: DateTime<Utc>, zone: Tz) -> Self {
        Self {
            date_time: value
                .with_timezone(&zone)
                .format("%Y-%m-%dT%H:%M:%S")
                .to_string(),
            time_zone: graph_time_zone_name(zone),
        }
    }
}

fn graph_time_zone_name(zone: Tz) -> String {
    match zone.name() {
        // Graph expects Windows time-zone IDs for dateTimeTimeZone and
        // recurrenceRange. Ho Chi Minh/Saigon/Bangkok share this offset and
        // daylight-saving behavior.
        "Asia/Ho_Chi_Minh" | "Asia/Saigon" | "Asia/Bangkok" => "SE Asia Standard Time".to_string(),
        "Asia/Singapore" | "Asia/Kuala_Lumpur" => "Singapore Standard Time".to_string(),
        "Asia/Tokyo" => "Tokyo Standard Time".to_string(),
        "Asia/Seoul" => "Korea Standard Time".to_string(),
        "Europe/London" => "GMT Standard Time".to_string(),
        "Europe/Paris" | "Europe/Berlin" | "Europe/Rome" | "Europe/Madrid" => {
            "W. Europe Standard Time".to_string()
        }
        "America/New_York" => "Eastern Standard Time".to_string(),
        "America/Chicago" => "Central Standard Time".to_string(),
        "America/Denver" => "Mountain Standard Time".to_string(),
        "America/Los_Angeles" => "Pacific Standard Time".to_string(),
        "Australia/Sydney" | "Australia/Melbourne" => "AUS Eastern Standard Time".to_string(),
        "Etc/UTC" | "UTC" => "UTC".to_string(),
        // Graph also accepts many Windows IDs and a documented set of IANA
        // IDs. Preserve the IANA name as the best fallback for less common
        // zones rather than silently changing the user's wall-clock time.
        name => name.to_string(),
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
    #[serde(default)]
    time_zone: String,
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
    #[serde(default)]
    show_as: Option<String>,
    #[serde(default)]
    sensitivity: Option<String>,
    #[serde(default)]
    is_reminder_on: bool,
    #[serde(default)]
    reminder_minutes_before_start: Option<i64>,
    recurrence: Option<Value>,
    created_date_time: Option<String>,
    last_modified_date_time: Option<String>,
}

impl MicrosoftEvent {
    fn into_model(self, calendar_id: &str) -> ProviderResult<CalendarEvent> {
        let start = parse_graph_datetime(&self.start)
            .with_context(|| format!("Microsoft event {} has an invalid start", self.id))?;
        let end = parse_graph_datetime(&self.end).unwrap_or_else(|_| {
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
        let recurrence = graph_recurrence_to_rrule(self.recurrence.as_ref(), start);
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

            preferences: EventPreferences {
                use_default_reminder: false,
                reminder_minutes: self.reminder_minutes_before_start.filter(|minutes| self.is_reminder_on && *minutes >= 0),
                availability: if self.show_as.as_deref() == Some("free") {
                    "free".to_string()
                } else {
                    "busy".to_string()
                },
                visibility: if self.sensitivity.as_deref() == Some("private") {
                    "private".to_string()
                } else {
                    "default".to_string()
                },
            },
            raw_payload: String::new(),
            created_at: created,
            updated_at: updated,
        })
    }
}

fn graph_recurrence_to_rrule(value: Option<&Value>, start: DateTime<Utc>) -> Vec<String> {
    let Some(value) = value else {
        return Vec::new();
    };
    let Some(pattern) = value.get("pattern") else {
        return Vec::new();
    };
    let frequency = match pattern.get("type").and_then(Value::as_str) {
        Some("daily") => "DAILY",
        Some("weekly") => "WEEKLY",
        Some("absoluteMonthly") => "MONTHLY",
        Some("absoluteYearly") => "YEARLY",
        _ => return Vec::new(),
    };
    let mut rule = format!("RRULE:FREQ={frequency}");
    if let Some(interval) = pattern.get("interval").and_then(Value::as_u64) {
        if interval > 1 {
            rule.push_str(&format!(";INTERVAL={interval}"));
        }
    }
    if frequency == "WEEKLY" {
        if let Some(days) = pattern.get("daysOfWeek").and_then(Value::as_array) {
            let codes: Vec<&str> = days
                .iter()
                .filter_map(Value::as_str)
                .filter_map(|day| match day {
                    "monday" => Some("MO"),
                    "tuesday" => Some("TU"),
                    "wednesday" => Some("WE"),
                    "thursday" => Some("TH"),
                    "friday" => Some("FR"),
                    "saturday" => Some("SA"),
                    "sunday" => Some("SU"),
                    _ => None,
                })
                .collect();
            if !codes.is_empty() {
                rule.push_str(";BYDAY=");
                rule.push_str(&codes.join(","));
            }
        }
    }
    if matches!(frequency, "MONTHLY" | "YEARLY") {
        let day = pattern
            .get("dayOfMonth")
            .and_then(Value::as_u64)
            .unwrap_or(start.day() as u64);
        rule.push_str(&format!(";BYMONTHDAY={}", day.clamp(1, 31)));
    }
    if let Some(range) = value.get("range") {
        match range.get("type").and_then(Value::as_str) {
            Some("numbered") => {
                if let Some(count) = range
                    .get("numberOfOccurrences")
                    .and_then(Value::as_u64)
                    .filter(|count| *count > 0)
                {
                    rule.push_str(&format!(";COUNT={count}"));
                }
            }
            Some("endDate") => {
                if let Some(end_date) = range.get("endDate").and_then(Value::as_str) {
                    let compact = graph_date_to_rrule(end_date);
                    if !compact.is_empty() {
                        rule.push_str(&format!(";UNTIL={compact}"));
                    }
                }
            }
            // `noEnd` is represented by numberOfOccurrences = 0 and a sentinel
            // endDate in Microsoft Graph.  Neither value is a valid RRULE bound.
            _ => {}
        }
    }
    vec![rule]
}

fn graph_date_to_rrule(value: &str) -> String {
    let value = value.trim();
    if value.len() >= 10
        && value.as_bytes().get(4) == Some(&b'-')
        && value.as_bytes().get(7) == Some(&b'-')
        && value.as_bytes()[0..4].iter().all(u8::is_ascii_digit)
        && value.as_bytes()[5..7].iter().all(u8::is_ascii_digit)
        && value.as_bytes()[8..10].iter().all(u8::is_ascii_digit)
    {
        return format!("{}{}{}", &value[0..4], &value[5..7], &value[8..10]);
    }
    if value.len() == 8 && value.bytes().all(|byte| byte.is_ascii_digit()) {
        return value.to_string();
    }
    String::new()
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

fn parse_graph_datetime(value: &MicrosoftDateTime) -> anyhow::Result<DateTime<Utc>> {
    if value.date_time.is_empty() {
        return Err(anyhow!("empty dateTime"));
    }
    if let Ok(date_time) = DateTime::parse_from_rfc3339(&value.date_time) {
        return Ok(date_time.with_timezone(&Utc));
    }
    let naive = NaiveDateTime::parse_from_str(&value.date_time, "%Y-%m-%dT%H:%M:%S%.f")
        .or_else(|_| NaiveDateTime::parse_from_str(&value.date_time, "%Y-%m-%dT%H:%M:%S"))?;
    let zone = graph_timezone(&value.time_zone).unwrap_or(chrono_tz::UTC);
    match zone.from_local_datetime(&naive) {
        LocalResult::Single(date_time) => Ok(date_time.with_timezone(&Utc)),
        LocalResult::Ambiguous(earliest, _) => Ok(earliest.with_timezone(&Utc)),
        LocalResult::None => Err(anyhow!(
            "dateTime {} does not exist in timezone {}",
            value.date_time,
            value.time_zone
        )),
    }
}

fn graph_timezone(value: &str) -> Option<Tz> {
    let value = value.trim();
    if value.is_empty() || value.eq_ignore_ascii_case("UTC") {
        return Some(chrono_tz::UTC);
    }
    let iana = match value {
        "SE Asia Standard Time" => "Asia/Ho_Chi_Minh",
        "Singapore Standard Time" => "Asia/Singapore",
        "Tokyo Standard Time" => "Asia/Tokyo",
        "Korea Standard Time" => "Asia/Seoul",
        "GMT Standard Time" => "Europe/London",
        "W. Europe Standard Time" => "Europe/Paris",
        "Eastern Standard Time" => "America/New_York",
        "Central Standard Time" => "America/Chicago",
        "Mountain Standard Time" => "America/Denver",
        "Pacific Standard Time" => "America/Los_Angeles",
        "AUS Eastern Standard Time" => "Australia/Sydney",
        other => other,
    };
    iana.parse::<Tz>().ok()
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

    #[test]
    fn single_reminder_and_monthly_interval_round_trip() {
        for minutes in [Some(0), Some(30), Some(1440), None] {
            for all_day in [false, true] {
                let mut draft = recurrence_draft("2026-10-04T00:00:00Z", "RRULE:FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=4");
                draft.all_day = all_day;
                draft.preferences.reminder_minutes = minutes;
                let mut value = serde_json::to_value(MicrosoftEventPayload::in_time_zone(&draft, chrono_tz::UTC)).unwrap();
                assert_eq!(value["isReminderOn"], minutes.is_some());
                assert_eq!(value["reminderMinutesBeforeStart"], minutes.unwrap_or(0));
                assert_eq!(value["recurrence"]["pattern"]["type"], "absoluteMonthly");
                assert_eq!(value["recurrence"]["pattern"]["interval"], 2);
                assert_eq!(value["recurrence"]["pattern"]["dayOfMonth"], 4);
                value["id"] = "test".into();
                let event: MicrosoftEvent = serde_json::from_value(value).unwrap();
                let model = event.into_model("calendar").unwrap();
                assert_eq!(model.preferences.reminder_minutes, minutes);
                assert_eq!(model.recurrence, draft.recurrence);
            }
        }
    }

    fn recurrence_draft(start: &str, rule: &str) -> EventDraft {
        let start = DateTime::parse_from_rfc3339(start)
            .unwrap()
            .with_timezone(&Utc);
        EventDraft {
            title: "Recurrence regression".into(),
            description: String::new(),
            location: String::new(),
            start,
            end: start + chrono::Duration::hours(1),
            all_day: false,
            recurrence: vec![rule.into()],

            preferences: EventPreferences::default(),
        }
    }

    #[test]
    fn friday_weekly_series_uses_local_dates_and_preserves_end_date() {
        let zone: Tz = "Asia/Ho_Chi_Minh".parse().unwrap();
        for hour in [0, 5, 10, 23] {
            let draft = recurrence_draft(
                &format!("2026-10-02T{hour:02}:00:00+07:00"),
                "RRULE:FREQ=WEEKLY;INTERVAL=1;UNTIL=20261024T235959Z",
            );
            let value =
                serde_json::to_value(MicrosoftEventPayload::in_time_zone(&draft, zone)).unwrap();
            assert_eq!(
                value["start"]["dateTime"],
                format!("2026-10-02T{hour:02}:00:00")
            );
            assert_eq!(value["start"]["timeZone"], "SE Asia Standard Time");
            assert_eq!(value["end"]["timeZone"], "SE Asia Standard Time");
            assert_eq!(
                value["recurrence"]["pattern"]["daysOfWeek"],
                serde_json::json!(["friday"])
            );
            assert_eq!(value["recurrence"]["pattern"]["interval"], 1);
            assert_eq!(value["recurrence"]["range"]["startDate"], "2026-10-02");
            assert_eq!(value["recurrence"]["range"]["endDate"], "2026-10-24");
            assert_eq!(
                value["recurrence"]["range"]["recurrenceTimeZone"],
                "SE Asia Standard Time"
            );
            assert_eq!(
                graph_recurrence_to_rrule(value.get("recurrence"), draft.start),
                vec!["RRULE:FREQ=WEEKLY;BYDAY=FR;UNTIL=20261024"]
            );
        }
    }

    #[test]
    fn explicit_weekdays_and_numbered_range_are_preserved() {
        let draft = recurrence_draft(
            "2026-10-02T05:00:00+07:00",
            "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR;COUNT=4",
        );
        let value = microsoft_recurrence(&draft, "Asia/Ho_Chi_Minh".parse().unwrap()).unwrap();
        assert_eq!(
            value["pattern"]["daysOfWeek"],
            serde_json::json!(["monday", "friday"])
        );
        assert_eq!(value["pattern"]["interval"], 2);
        assert_eq!(value["range"]["numberOfOccurrences"], 4);
    }

    #[test]
    fn monthly_and_yearly_patterns_use_local_day_and_month() {
        for frequency in ["MONTHLY", "YEARLY"] {
            let draft = recurrence_draft(
                "2027-01-01T01:00:00+07:00",
                &format!("RRULE:FREQ={frequency}"),
            );
            let value = microsoft_recurrence(&draft, "Asia/Ho_Chi_Minh".parse().unwrap()).unwrap();
            assert_eq!(value["pattern"]["dayOfMonth"], 1);
            assert_eq!(value["range"]["startDate"], "2027-01-01");
            if frequency == "YEARLY" {
                assert_eq!(value["pattern"]["month"], 1);
            }
        }
    }

    #[test]
    fn all_day_series_keeps_date_only_utc_encoding() {
        let mut draft = recurrence_draft("2026-10-02T00:00:00Z", "RRULE:FREQ=WEEKLY");
        draft.all_day = true;
        draft.end = draft.start + chrono::Duration::days(1);
        let value = serde_json::to_value(MicrosoftEventPayload::in_time_zone(
            &draft,
            "America/Los_Angeles".parse().unwrap(),
        ))
        .unwrap();
        assert_eq!(value["start"]["dateTime"], "2026-10-02T00:00:00");
        assert_eq!(value["start"]["timeZone"], "UTC");
        assert_eq!(value["end"]["dateTime"], "2026-10-03T00:00:00");
        assert_eq!(
            value["recurrence"]["pattern"]["daysOfWeek"],
            serde_json::json!(["friday"])
        );
    }

    #[test]
    fn parses_graph_wall_clock_time_in_its_declared_timezone() {
        let start = MicrosoftDateTime {
            date_time: "2026-10-02T08:00:00.0000000".into(),
            time_zone: "SE Asia Standard Time".into(),
        };
        let end = MicrosoftDateTime {
            date_time: "2026-10-02T11:00:00.0000000".into(),
            time_zone: "SE Asia Standard Time".into(),
        };
        assert_eq!(
            parse_graph_datetime(&start).unwrap().to_rfc3339(),
            "2026-10-02T01:00:00+00:00"
        );
        assert_eq!(
            parse_graph_datetime(&end).unwrap().to_rfc3339(),
            "2026-10-02T04:00:00+00:00"
        );
    }

    #[test]
    fn parses_graph_utc_when_timezone_is_missing() {
        let value = MicrosoftDateTime {
            date_time: "2026-10-02T08:00:00.0000000".into(),
            time_zone: String::new(),
        };
        assert_eq!(
            parse_graph_datetime(&value).unwrap().to_rfc3339(),
            "2026-10-02T08:00:00+00:00"
        );
    }

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
            default_reminder_minutes: None,
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
    fn sync_uses_event_collection_for_all_calendars() {
        assert_eq!(
            MicrosoftProvider::calendar_events_url(&calendar(true))
                .expect("default calendar URL")
                .path(),
            "/v1.0/me/calendars/remote-calendar/events"
        );
        assert_eq!(
            MicrosoftProvider::calendar_events_url(&calendar(false))
                .expect("secondary calendar URL")
                .path(),
            "/v1.0/me/calendars/remote-calendar/events"
        );
    }

    #[test]
    fn graph_no_end_does_not_emit_count_zero() {
        let value = serde_json::json!({
            "pattern": {
                "type": "weekly",
                "interval": 1,
                "daysOfWeek": ["thursday"]
            },
            "range": {
                "type": "noEnd",
                "numberOfOccurrences": 0,
                "endDate": "0001-01-01"
            }
        });
        let start = Utc.with_ymd_and_hms(2026, 10, 1, 14, 0, 0).unwrap();
        assert_eq!(
            graph_recurrence_to_rrule(Some(&value), start),
            vec!["RRULE:FREQ=WEEKLY;BYDAY=TH"]
        );
    }

    #[test]
    fn graph_numbered_and_end_date_ranges_are_bounded() {
        let numbered = serde_json::json!({
            "pattern": {"type": "weekly", "daysOfWeek": ["thursday"]},
            "range": {"type": "numbered", "numberOfOccurrences": 3}
        });
        let end_date = serde_json::json!({
            "pattern": {"type": "weekly", "daysOfWeek": ["thursday"]},
            "range": {"type": "endDate", "endDate": "2026-12-31"}
        });
        let start = Utc.with_ymd_and_hms(2026, 10, 1, 14, 0, 0).unwrap();
        assert_eq!(
            graph_recurrence_to_rrule(Some(&numbered), start),
            vec!["RRULE:FREQ=WEEKLY;BYDAY=TH;COUNT=3"]
        );
        assert_eq!(
            graph_recurrence_to_rrule(Some(&end_date), start),
            vec!["RRULE:FREQ=WEEKLY;BYDAY=TH;UNTIL=20261231"]
        );
    }
}
