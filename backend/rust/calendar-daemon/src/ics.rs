use crate::model::EventDraft;
use anyhow::{Context, Result, anyhow};
use chrono::{DateTime, Duration, NaiveDate, TimeZone, Utc};
use icalendar::{
    Calendar as ICalendar, CalendarDateTime, Component, DatePerhapsTime, EventLike,
};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ParsedIcsEvent {
    pub title: String,
    pub description: String,
    pub location: String,
    pub start: String,
    pub end: String,
    pub all_day: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ParsedIcsSummary {
    pub file_name: String,
    pub total_events: usize,
    pub events_preview: Vec<ParsedIcsEvent>,
}

pub fn parse_ics_file(path: &Path) -> Result<(ParsedIcsSummary, Vec<EventDraft>)> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("read iCalendar file {}", path.display()))?;
    let file_name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("events.ics")
        .to_string();
    parse_ics_content(&content, &file_name)
}

pub fn parse_ics_content(content: &str, file_name: &str) -> Result<(ParsedIcsSummary, Vec<EventDraft>)> {
    let calendar: ICalendar = content
        .parse()
        .map_err(|err: String| anyhow!("parse iCalendar content: {err}"))?;

    let mut drafts = Vec::new();
    for event in calendar.events() {
        let status = event
            .property_value("STATUS")
            .unwrap_or("CONFIRMED")
            .to_ascii_lowercase();
        if status == "cancelled" {
            continue;
        }

        let Some(start_value) = event.get_start() else {
            continue;
        };
        let (start, all_day) = match ical_time(start_value) {
            Ok(time) => time,
            Err(_) => continue,
        };

        let end = event
            .get_end()
            .and_then(|end_val| ical_time(end_val).ok())
            .map(|(dt, _)| dt)
            .unwrap_or_else(|| {
                start
                    + if all_day {
                        Duration::days(1)
                    } else {
                        Duration::hours(1)
                    }
            });

        let effective_end = if end <= start {
            start
                + if all_day {
                    Duration::days(1)
                } else {
                    Duration::hours(1)
                }
        } else {
            end
        };

        let title = event
            .get_summary()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .unwrap_or("Untitled Event")
            .to_string();
        let description = event.get_description().unwrap_or_default().to_string();
        let location = event.get_location().unwrap_or_default().to_string();

        drafts.push(EventDraft {
            title,
            description,
            location,
            start,
            end: effective_end,
            all_day,
        });
    }

    if drafts.is_empty() {
        anyhow::bail!("No valid calendar events found in this iCalendar file");
    }

    // Sort events chronologically
    drafts.sort_by_key(|d| d.start);

    let preview_limit = 20;
    let events_preview: Vec<ParsedIcsEvent> = drafts
        .iter()
        .take(preview_limit)
        .map(|d| ParsedIcsEvent {
            title: d.title.clone(),
            description: d.description.clone(),
            location: d.location.clone(),
            start: d.start.to_rfc3339(),
            end: d.end.to_rfc3339(),
            all_day: d.all_day,
        })
        .collect();

    let summary = ParsedIcsSummary {
        file_name: file_name.to_string(),
        total_events: drafts.len(),
        events_preview,
    };

    Ok((summary, drafts))
}

pub fn ical_time(value: DatePerhapsTime) -> Result<(DateTime<Utc>, bool)> {
    match value {
        DatePerhapsTime::Date(date) => Ok((utc_midnight(date), true)),
        DatePerhapsTime::DateTime(CalendarDateTime::Utc(date_time)) => Ok((date_time, false)),
        DatePerhapsTime::DateTime(CalendarDateTime::Floating(date_time)) => {
            Ok((Utc.from_utc_datetime(&date_time), false))
        }
        DatePerhapsTime::DateTime(value @ CalendarDateTime::WithTimezone { .. }) => {
            if let Some(date_time) = value.try_into_utc() {
                Ok((date_time, false))
            } else {
                match value {
                    CalendarDateTime::WithTimezone { date_time, .. } => {
                        Ok((Utc.from_utc_datetime(&date_time), false))
                    }
                    _ => anyhow::bail!("unsupported time zone"),
                }
            }
        }
    }
}

pub fn utc_midnight(date: NaiveDate) -> DateTime<Utc> {
    Utc.from_utc_datetime(&date.and_hms_opt(0, 0, 0).unwrap())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_ics_events_successfully() {
        let sample = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Example Corp.//EN
BEGIN:VEVENT
UID:event-1
DTSTART:20260920T100000Z
DTEND:20260920T113000Z
SUMMARY:Team Meeting
LOCATION:Room 402
DESCRIPTION:Weekly sync
END:VEVENT
BEGIN:VEVENT
UID:event-2
DTSTART;VALUE=DATE:20260921
DTEND;VALUE=DATE:20260922
SUMMARY:Company Holiday
END:VEVENT
BEGIN:VEVENT
UID:event-3-cancelled
DTSTART:20260922T140000Z
DTEND:20260922T150000Z
STATUS:CANCELLED
SUMMARY:Old Meeting
END:VEVENT
END:VCALENDAR
";

        let (summary, drafts) = parse_ics_content(sample, "test.ics").expect("parse success");
        assert_eq!(summary.file_name, "test.ics");
        assert_eq!(summary.total_events, 2);
        assert_eq!(drafts.len(), 2);

        assert_eq!(drafts[0].title, "Team Meeting");
        assert_eq!(drafts[0].location, "Room 402");
        assert_eq!(drafts[0].all_day, false);

        assert_eq!(drafts[1].title, "Company Holiday");
        assert_eq!(drafts[1].all_day, true);
    }
}
