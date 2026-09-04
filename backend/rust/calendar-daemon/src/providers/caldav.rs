use super::{
    CALDAV_PASSWORD_KEY, CalendarProvider, ProviderError, ProviderResult, SyncWindow,
    response_error,
};
use crate::keyring::Keyring;
use crate::model::{
    Account, Calendar, CalendarEvent, EventChange, EventDraft, ProviderKind, RemoteCalendar,
    SyncBatch,
};
use anyhow::{Context, anyhow};
use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, TimeZone, Utc};
use icalendar::{
    Calendar as ICalendar, CalendarDateTime, Component, DatePerhapsTime, Event as IEvent, EventLike,
};
use quick_xml::Reader;
use quick_xml::events::Event as XmlEvent;
use reqwest::{Client, Method, StatusCode};
use serde_json::Value;
use url::Url;
use uuid::Uuid;

const ICLOUD_ENDPOINT: &str = "https://caldav.icloud.com/";

#[derive(Clone)]
pub struct CalDavProvider {
    http: Client,
    keyring: Keyring,
}

impl CalDavProvider {
    pub fn new(http: Client, keyring: Keyring) -> Self {
        Self { http, keyring }
    }

    async fn credentials(&self, account: &Account) -> ProviderResult<(String, String, Url)> {
        let username = account
            .config
            .get("username")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .unwrap_or(&account.email)
            .to_string();
        let password = self
            .keyring
            .get_text(&account.id, CALDAV_PASSWORD_KEY)
            .await?
            .ok_or_else(|| {
                ProviderError::Reauth("CalDAV app-specific password is missing".to_string())
            })?;
        let endpoint = account
            .config
            .get("server")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .unwrap_or(ICLOUD_ENDPOINT);
        Ok((username, password, Url::parse(endpoint)?))
    }

    async fn discover_home(
        &self,
        endpoint: &Url,
        username: &str,
        password: &str,
    ) -> ProviderResult<Url> {
        let principal_body = r#"<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>"#;
        let principal_response = self
            .dav_request(
                "PROPFIND",
                endpoint.clone(),
                username,
                password,
                principal_body,
                "0",
            )
            .await?;
        let principal = parse_multistatus(&principal_response)?
            .into_iter()
            .find_map(|response| response.principal)
            .context("CalDAV server did not return current-user-principal")?;
        let principal_url = endpoint.join(&principal)?;

        let home_body = r#"<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-home-set/></d:prop>
</d:propfind>"#;
        let home_response = self
            .dav_request(
                "PROPFIND",
                principal_url,
                username,
                password,
                home_body,
                "0",
            )
            .await?;
        let home = parse_multistatus(&home_response)?
            .into_iter()
            .find_map(|response| response.calendar_home)
            .context("CalDAV server did not return calendar-home-set")?;
        Ok(endpoint.join(&home)?)
    }

    async fn dav_request(
        &self,
        method: &str,
        url: Url,
        username: &str,
        password: &str,
        body: &str,
        depth: &str,
    ) -> ProviderResult<String> {
        let response = self
            .http
            .request(
                Method::from_bytes(method.as_bytes()).map_err(anyhow::Error::from)?,
                url,
            )
            .basic_auth(username, Some(password))
            .header("Depth", depth)
            .header("Content-Type", "application/xml; charset=utf-8")
            .body(body.to_string())
            .send()
            .await?;
        if matches!(
            response.status(),
            StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN
        ) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() && response.status().as_u16() != 207 {
            return Err(anyhow!(response_error(response).await).into());
        }
        Ok(response.text().await?)
    }

    fn event_resource_url(calendar: &Calendar, remote_id: &str) -> ProviderResult<Url> {
        let href = remote_id.split('#').next().unwrap_or_default();
        if href.is_empty() {
            return Err(anyhow!("CalDAV event is missing its resource URL").into());
        }
        if let Ok(url) = Url::parse(href) {
            return Ok(url);
        }
        Ok(Url::parse(&calendar.remote_id)?.join(href)?)
    }

    async fn put_event(
        &self,
        account: &Account,
        resource_url: Url,
        uid: &str,
        draft: &EventDraft,
        etag: Option<&str>,
    ) -> ProviderResult<(String, String)> {
        let (username, password, _) = self.credentials(account).await?;
        let payload = build_ical_event(uid, draft);
        let mut request = self
            .http
            .put(resource_url)
            .basic_auth(username, Some(password))
            .header("Content-Type", "text/calendar; charset=utf-8")
            .body(payload.clone());
        request = match etag {
            Some(etag) if !etag.is_empty() => request.header("If-Match", etag),
            Some(_) => request,
            None => request.header("If-None-Match", "*"),
        };
        let response = request.send().await?;
        if matches!(
            response.status(),
            StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN
        ) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() {
            return Err(anyhow!(response_error(response).await).into());
        }
        let etag = response
            .headers()
            .get(reqwest::header::ETAG)
            .and_then(|value| value.to_str().ok())
            .unwrap_or_default()
            .to_string();
        Ok((etag, payload))
    }
}

#[async_trait]
impl CalendarProvider for CalDavProvider {
    fn kind(&self) -> ProviderKind {
        ProviderKind::CalDav
    }

    async fn list_calendars(&self, account: &Account) -> ProviderResult<Vec<RemoteCalendar>> {
        let (username, password, endpoint) = self.credentials(account).await?;
        let home = self.discover_home(&endpoint, &username, &password).await?;
        let body = r#"<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:a="http://apple.com/ns/ical/">
  <d:prop>
    <d:displayname/><d:resourcetype/><c:supported-calendar-component-set/>
    <a:calendar-color/><c:calendar-description/>
  </d:prop>
</d:propfind>"#;
        let response = self
            .dav_request("PROPFIND", home.clone(), &username, &password, body, "1")
            .await?;
        let calendars = parse_multistatus(&response)?
            .into_iter()
            .filter(|response| response.is_calendar && !response.href.is_empty())
            .map(|response| {
                let name = if response.display_name.is_empty() {
                    response.href.trim_matches('/').to_string()
                } else {
                    response.display_name
                };
                RemoteCalendar {
                    remote_id: home
                        .join(&response.href)
                        .map(|url| url.to_string())
                        .unwrap_or(response.href),
                    name,
                    description: response.description,
                    color: normalize_color(&response.color),
                    time_zone: String::new(),
                    primary: false,
                    read_only: false,
                }
            })
            .collect();
        Ok(calendars)
    }

    async fn sync_calendar(
        &self,
        account: &Account,
        calendar: &Calendar,
        window: SyncWindow,
    ) -> ProviderResult<SyncBatch> {
        let (username, password, _) = self.credentials(account).await?;
        let calendar_url = Url::parse(&calendar.remote_id)?;
        let start = window.start.format("%Y%m%dT%H%M%SZ");
        let end = window.end.format("%Y%m%dT%H%M%SZ");
        let body = format!(
            r#"<?xml version="1.0" encoding="UTF-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data/></d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VEVENT"><c:time-range start="{start}" end="{end}"/></c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>"#
        );
        let response = self
            .dav_request("REPORT", calendar_url, &username, &password, &body, "1")
            .await?;
        let mut changes = Vec::new();
        for resource in parse_multistatus(&response)? {
            if resource.calendar_data.trim().is_empty() {
                continue;
            }
            changes.extend(parse_ical_resource(
                &calendar.id,
                &resource.href,
                &resource.etag,
                &resource.calendar_data,
            )?);
        }
        Ok(SyncBatch {
            changes,
            next_token: String::new(),
            full_snapshot: true,
        })
    }

    async fn create_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        draft: &EventDraft,
    ) -> ProviderResult<CalendarEvent> {
        let uid = Uuid::new_v4().to_string();
        let calendar_url = Url::parse(&calendar.remote_id)?;
        let resource_url = calendar_url.join(&format!("{uid}.ics"))?;
        let (etag, raw_payload) = self
            .put_event(account, resource_url.clone(), &uid, draft, None)
            .await?;
        let now = Utc::now();
        Ok(CalendarEvent {
            id: Uuid::new_v4().to_string(),
            calendar_id: calendar.id.clone(),
            remote_id: format!("{}#{uid}#", resource_url.path()),
            uid,
            etag,
            title: draft.title.clone(),
            description: draft.description.clone(),
            location: draft.location.clone(),
            start: draft.start,
            end: draft.end,
            all_day: draft.all_day,
            status: "confirmed".to_string(),
            recurrence: Vec::new(),
            raw_payload,
            created_at: now,
            updated_at: now,
        })
    }

    async fn update_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        event: &CalendarEvent,
        draft: &EventDraft,
    ) -> ProviderResult<CalendarEvent> {
        let uid = if event.uid.is_empty() {
            Uuid::new_v4().to_string()
        } else {
            event.uid.clone()
        };
        let resource_url = Self::event_resource_url(calendar, &event.remote_id)?;
        let (etag, raw_payload) = self
            .put_event(account, resource_url, &uid, draft, Some(&event.etag))
            .await?;
        Ok(CalendarEvent {
            id: event.id.clone(),
            calendar_id: calendar.id.clone(),
            remote_id: event.remote_id.clone(),
            uid,
            etag,
            title: draft.title.clone(),
            description: draft.description.clone(),
            location: draft.location.clone(),
            start: draft.start,
            end: draft.end,
            all_day: draft.all_day,
            status: "confirmed".to_string(),
            recurrence: event.recurrence.clone(),
            raw_payload,
            created_at: event.created_at,
            updated_at: Utc::now(),
        })
    }

    async fn delete_event(
        &self,
        account: &Account,
        calendar: &Calendar,
        event: &CalendarEvent,
    ) -> ProviderResult<()> {
        let (username, password, _) = self.credentials(account).await?;
        let response = self
            .http
            .delete(Self::event_resource_url(calendar, &event.remote_id)?)
            .basic_auth(username, Some(password))
            .send()
            .await?;
        if matches!(
            response.status(),
            StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN
        ) {
            return Err(ProviderError::Reauth(response_error(response).await));
        }
        if !response.status().is_success() && response.status() != StatusCode::NOT_FOUND {
            return Err(anyhow!(response_error(response).await).into());
        }
        Ok(())
    }
}

fn build_ical_event(uid: &str, draft: &EventDraft) -> String {
    let mut event = IEvent::new();
    event
        .uid(uid)
        .summary(&draft.title)
        .description(&draft.description)
        .location(&draft.location);
    if draft.all_day {
        event
            .starts(draft.start.date_naive())
            .ends(draft.end.date_naive());
    } else {
        event.starts(draft.start).ends(draft.end);
    }
    let mut calendar = ICalendar::new();
    calendar.push(event.done());
    calendar.to_string()
}

#[derive(Clone, Debug, Default)]
struct DavResponse {
    href: String,
    display_name: String,
    description: String,
    color: String,
    etag: String,
    calendar_data: String,
    principal: Option<String>,
    calendar_home: Option<String>,
    is_calendar: bool,
}

fn parse_multistatus(xml: &str) -> ProviderResult<Vec<DavResponse>> {
    let mut reader = Reader::from_str(xml);
    reader.config_mut().trim_text(true);
    let mut responses = Vec::new();
    let mut current: Option<DavResponse> = None;
    let mut tag_stack: Vec<String> = Vec::new();
    let mut saw_multistatus = false;

    loop {
        match reader.read_event() {
            Ok(XmlEvent::Start(start)) => {
                let name = start.local_name().as_ref().to_string();
                if name == "multistatus" {
                    saw_multistatus = true;
                } else if name == "response" {
                    current = Some(DavResponse::default());
                } else if name == "calendar"
                    && let Some(response) = current.as_mut()
                {
                    response.is_calendar = true;
                }
                tag_stack.push(name);
            }
            Ok(XmlEvent::Empty(empty)) => {
                let name = empty.local_name().as_ref().to_string();
                if name == "multistatus" {
                    saw_multistatus = true;
                } else if name == "calendar"
                    && let Some(response) = current.as_mut()
                {
                    response.is_calendar = true;
                }
            }
            Ok(XmlEvent::Text(text)) => {
                if let Some(response) = current.as_mut() {
                    let value = quick_xml::escape::unescape(text.as_ref())
                        .map_err(anyhow::Error::from)?
                        .into_owned();
                    assign_xml_value(response, &tag_stack, value);
                }
            }
            Ok(XmlEvent::CData(text)) => {
                if let Some(response) = current.as_mut() {
                    let value = text.as_ref().to_string();
                    assign_xml_value(response, &tag_stack, value);
                }
            }
            Ok(XmlEvent::End(end)) => {
                let name = end.local_name();
                if name.as_ref() == "response"
                    && let Some(response) = current.take()
                {
                    responses.push(response);
                }
                match tag_stack.pop() {
                    Some(expected) if expected == name.as_ref() => {}
                    Some(expected) => {
                        return Err(anyhow!(
                            "parse CalDAV multistatus response: expected </{expected}>, found </{}>",
                            name.as_ref()
                        )
                        .into());
                    }
                    None => {
                        return Err(anyhow!(
                            "parse CalDAV multistatus response: unexpected closing tag </{}>",
                            name.as_ref()
                        )
                        .into());
                    }
                }
            }
            Ok(XmlEvent::Eof) => {
                if !saw_multistatus {
                    return Err(anyhow!("CalDAV response did not contain DAV:multistatus").into());
                }
                if let Some(tag) = tag_stack.last() {
                    return Err(
                        anyhow!("parse CalDAV multistatus response: unclosed <{tag}> tag").into(),
                    );
                }
                break;
            }
            Err(error) => {
                return Err(anyhow!("parse CalDAV multistatus response: {error}").into());
            }
            _ => {}
        }
    }
    Ok(responses)
}

fn assign_xml_value(response: &mut DavResponse, tags: &[String], value: String) {
    let Some(tag) = tags.last().map(String::as_str) else {
        return;
    };
    match tag {
        "href" => {
            let parent = tags.iter().rev().nth(1).map(String::as_str);
            match parent {
                Some("current-user-principal") => response.principal = Some(value),
                Some("calendar-home-set") => response.calendar_home = Some(value),
                _ if response.href.is_empty() => response.href = value,
                _ => {}
            }
        }
        "displayname" => response.display_name = value,
        "calendar-description" => response.description = value,
        "calendar-color" => response.color = value,
        "getetag" => response.etag = value,
        "calendar-data" => response.calendar_data.push_str(&value),
        _ => {}
    }
}

fn parse_ical_resource(
    calendar_id: &str,
    href: &str,
    etag: &str,
    source: &str,
) -> ProviderResult<Vec<EventChange>> {
    let calendar: ICalendar = source
        .parse()
        .map_err(|error: String| anyhow!("parse CalDAV resource {href}: {error}"))?;
    let mut changes = Vec::new();
    for event in calendar.events() {
        let Some(start_value) = event.get_start() else {
            continue;
        };
        let (start, all_day) = ical_time(start_value)?;
        let end = event
            .get_end()
            .map(ical_time)
            .transpose()?
            .map(|(date_time, _)| date_time)
            .unwrap_or_else(|| {
                start
                    + if all_day {
                        chrono::Duration::days(1)
                    } else {
                        chrono::Duration::hours(1)
                    }
            });
        let uid = event.get_uid().unwrap_or(href).to_string();
        let recurrence_id = event.property_value("RECURRENCE-ID").unwrap_or_default();
        let remote_id = format!("{href}#{uid}#{recurrence_id}");
        let recurrence = event
            .property_value("RRULE")
            .map(|rule| vec![rule.to_string()])
            .unwrap_or_default();
        let status = event
            .property_value("STATUS")
            .unwrap_or("CONFIRMED")
            .to_ascii_lowercase();
        if status == "cancelled" {
            changes.push(EventChange::Delete { remote_id });
            continue;
        }
        let now = Utc::now();
        changes.push(EventChange::Upsert(Box::new(CalendarEvent {
            id: Uuid::new_v4().to_string(),
            calendar_id: calendar_id.to_string(),
            remote_id,
            uid,
            etag: etag.to_string(),
            title: event.get_summary().unwrap_or_default().to_string(),
            description: event.get_description().unwrap_or_default().to_string(),
            location: event.get_location().unwrap_or_default().to_string(),
            start,
            end,
            all_day,
            status,
            recurrence,
            raw_payload: event.to_string(),
            created_at: now,
            updated_at: now,
        })));
    }
    Ok(changes)
}

fn ical_time(value: DatePerhapsTime) -> ProviderResult<(DateTime<Utc>, bool)> {
    match value {
        DatePerhapsTime::Date(date) => Ok((utc_midnight(date), true)),
        DatePerhapsTime::DateTime(CalendarDateTime::Utc(date_time)) => Ok((date_time, false)),
        DatePerhapsTime::DateTime(CalendarDateTime::Floating(date_time)) => {
            Ok((Utc.from_utc_datetime(&date_time), false))
        }
        DatePerhapsTime::DateTime(value @ CalendarDateTime::WithTimezone { .. }) => value
            .try_into_utc()
            .map(|date_time| (date_time, false))
            .ok_or_else(|| anyhow!("unsupported CalDAV time zone").into()),
    }
}

fn utc_midnight(date: NaiveDate) -> DateTime<Utc> {
    Utc.from_utc_datetime(&date.and_hms_opt(0, 0, 0).unwrap())
}

fn normalize_color(color: &str) -> String {
    let color = color.trim();
    if color.len() == 9 && color.starts_with('#') {
        color[..7].to_string()
    } else {
        color.to_string()
    }
}

pub fn default_icloud_endpoint() -> &'static str {
    ICLOUD_ENDPOINT
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_dav_properties() {
        let xml = r#"<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response><d:href>/calendars/test/home/</d:href><d:propstat><d:prop>
    <d:displayname>Home</d:displayname><d:resourcetype><c:calendar/></d:resourcetype>
  </d:prop></d:propstat></d:response>
</d:multistatus>"#;
        let responses = parse_multistatus(xml).expect("parse DAV response");
        assert_eq!(responses.len(), 1);
        assert_eq!(responses[0].display_name, "Home");
        assert!(responses[0].is_calendar);
    }

    #[test]
    fn parses_basic_ical_event() {
        let source = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:test\r\nDTSTART:20260902T080000Z\r\nDTEND:20260902T090000Z\r\nSUMMARY:Test\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        let changes =
            parse_ical_resource("calendar", "/test.ics", "etag", source).expect("parse event");
        assert_eq!(changes.len(), 1);
    }

    #[test]
    fn rejects_malformed_multistatus_xml() {
        assert!(parse_multistatus("<multistatus><response>").is_err());
    }
}
