use crate::model::{
    Account, Calendar, CalendarEvent, EventChange, ProviderKind, RemoteCalendar, SyncBatch,
};
use anyhow::{Context, Result, anyhow};
use chrono::{DateTime, Utc};
use rusqlite::{Connection, OptionalExtension, Row, params};
use std::collections::HashSet;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::str::FromStr;
use std::sync::{Arc, Mutex, MutexGuard};
use uuid::Uuid;

const INITIAL_MIGRATION: &str = include_str!("../migrations/001_initial.sql");
const EVENT_REMINDERS_MIGRATION: &str = include_str!("../migrations/002_event_reminders.sql");

#[derive(Clone)]
pub struct Database {
    connection: Arc<Mutex<Connection>>,
}

impl Database {
    pub fn open(path: &Path) -> Result<Self> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("create database directory {}", parent.display()))?;
        }

        let connection = Connection::open(path)
            .with_context(|| format!("open calendar database {}", path.display()))?;
        connection.execute_batch(
            r#"
            PRAGMA foreign_keys = ON;
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;
            PRAGMA busy_timeout = 5000;
            "#,
        )?;
        connection.execute_batch(INITIAL_MIGRATION)?;
        connection.execute_batch(EVENT_REMINDERS_MIGRATION)?;

        fs::set_permissions(path, fs::Permissions::from_mode(0o600))
            .with_context(|| format!("set database permissions {}", path.display()))?;

        Ok(Self {
            connection: Arc::new(Mutex::new(connection)),
        })
    }

    fn connection(&self) -> Result<MutexGuard<'_, Connection>> {
        self.connection
            .lock()
            .map_err(|_| anyhow!("calendar database lock was poisoned"))
    }

    pub fn list_accounts(&self, enabled_only: bool) -> Result<Vec<Account>> {
        let connection = self.connection()?;
        let mut statement = connection.prepare(if enabled_only {
            r#"
            SELECT id, provider, display_name, email, config_json, enabled, needs_reauth,
                   last_error, last_sync_at, created_at, updated_at
            FROM accounts
            WHERE enabled = 1
            ORDER BY created_at
            "#
        } else {
            r#"
            SELECT id, provider, display_name, email, config_json, enabled, needs_reauth,
                   last_error, last_sync_at, created_at, updated_at
            FROM accounts
            ORDER BY created_at
            "#
        })?;
        let rows = statement.query_map([], account_from_row)?;
        rows.collect::<rusqlite::Result<Vec<_>>>()
            .map_err(Into::into)
    }

    pub fn get_account(&self, id: &str) -> Result<Option<Account>> {
        let connection = self.connection()?;
        connection
            .query_row(
                r#"
                SELECT id, provider, display_name, email, config_json, enabled, needs_reauth,
                       last_error, last_sync_at, created_at, updated_at
                FROM accounts
                WHERE id = ?1
                "#,
                [id],
                account_from_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn upsert_account(&self, account: &Account) -> Result<()> {
        let connection = self.connection()?;
        connection.execute(
            r#"
            INSERT INTO accounts(
                id, provider, display_name, email, config_json, enabled, needs_reauth,
                last_error, last_sync_at, created_at, updated_at
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
            ON CONFLICT(id) DO UPDATE SET
                provider = excluded.provider,
                display_name = excluded.display_name,
                email = excluded.email,
                config_json = excluded.config_json,
                enabled = excluded.enabled,
                needs_reauth = excluded.needs_reauth,
                last_error = excluded.last_error,
                last_sync_at = excluded.last_sync_at,
                updated_at = excluded.updated_at
            "#,
            params![
                account.id,
                account.provider.as_str(),
                account.display_name,
                account.email,
                account.config.to_string(),
                account.enabled,
                account.needs_reauth,
                account.last_error,
                account.last_sync_at.map(format_time),
                format_time(account.created_at),
                format_time(account.updated_at),
            ],
        )?;
        Ok(())
    }

    pub fn delete_account(&self, id: &str) -> Result<bool> {
        let connection = self.connection()?;
        Ok(connection.execute("DELETE FROM accounts WHERE id = ?1", [id])? > 0)
    }

    pub fn set_account_sync_success(&self, id: &str) -> Result<()> {
        let now = format_time(Utc::now());
        let connection = self.connection()?;
        connection.execute(
            r#"
            UPDATE accounts
            SET needs_reauth = 0, last_error = '', last_sync_at = ?2, updated_at = ?2
            WHERE id = ?1
            "#,
            params![id, now],
        )?;
        Ok(())
    }

    pub fn set_account_sync_error(&self, id: &str, error: &str, needs_reauth: bool) -> Result<()> {
        let connection = self.connection()?;
        connection.execute(
            "UPDATE accounts SET needs_reauth = ?2, last_error = ?3, updated_at = ?4 WHERE id = ?1",
            params![id, needs_reauth, error, format_time(Utc::now())],
        )?;
        Ok(())
    }

    pub fn set_account_enabled(&self, id: &str, enabled: bool) -> Result<bool> {
        let connection = self.connection()?;
        Ok(connection.execute(
            "UPDATE accounts SET enabled = ?2, updated_at = ?3 WHERE id = ?1",
            params![id, enabled, format_time(Utc::now())],
        )? > 0)
    }

    pub fn reconcile_calendars(
        &self,
        account_id: &str,
        remote_calendars: &[RemoteCalendar],
    ) -> Result<Vec<Calendar>> {
        let mut connection = self.connection()?;
        let transaction = connection.transaction()?;
        let now = format_time(Utc::now());

        for calendar in remote_calendars {
            let existing_id: Option<String> = transaction
                .query_row(
                    "SELECT id FROM calendars WHERE account_id = ?1 AND remote_id = ?2",
                    params![account_id, calendar.remote_id],
                    |row| row.get(0),
                )
                .optional()?;
            let id = existing_id.unwrap_or_else(|| Uuid::new_v4().to_string());
            transaction.execute(
                r#"
                INSERT INTO calendars(
                    id, account_id, remote_id, name, description, color, time_zone, is_primary,
                    read_only, visible, sync_token, created_at, updated_at
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 1, '', ?10, ?10)
                ON CONFLICT(account_id, remote_id) DO UPDATE SET
                    name = excluded.name,
                    description = excluded.description,
                    color = excluded.color,
                    time_zone = excluded.time_zone,
                    is_primary = excluded.is_primary,
                    read_only = excluded.read_only,
                    updated_at = excluded.updated_at
                "#,
                params![
                    id,
                    account_id,
                    calendar.remote_id,
                    calendar.name,
                    calendar.description,
                    calendar.color,
                    calendar.time_zone,
                    calendar.primary,
                    calendar.read_only,
                    now,
                ],
            )?;
        }

        let remote_ids = remote_calendars
            .iter()
            .map(|calendar| calendar.remote_id.as_str())
            .collect::<HashSet<_>>();
        let existing = {
            let mut statement =
                transaction.prepare("SELECT id, remote_id FROM calendars WHERE account_id = ?1")?;
            statement
                .query_map([account_id], |row| {
                    Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
                })?
                .collect::<rusqlite::Result<Vec<_>>>()?
        };
        for (id, remote_id) in existing {
            if !remote_ids.contains(remote_id.as_str()) {
                transaction.execute("DELETE FROM calendars WHERE id = ?1", [id])?;
            }
        }

        transaction.commit()?;
        drop(connection);
        self.list_calendars(Some(account_id))
    }

    pub fn list_calendars(&self, account_id: Option<&str>) -> Result<Vec<Calendar>> {
        let connection = self.connection()?;
        let sql = if account_id.is_some() {
            r#"
            SELECT id, account_id, remote_id, name, description, color, time_zone, is_primary,
                   read_only, visible, sync_token, created_at, updated_at
            FROM calendars
            WHERE account_id = ?1
            ORDER BY name COLLATE NOCASE
            "#
        } else {
            r#"
            SELECT id, account_id, remote_id, name, description, color, time_zone, is_primary,
                   read_only, visible, sync_token, created_at, updated_at
            FROM calendars
            ORDER BY name COLLATE NOCASE
            "#
        };
        let mut statement = connection.prepare(sql)?;
        let calendars = match account_id {
            Some(account_id) => statement
                .query_map([account_id], calendar_from_row)?
                .collect::<rusqlite::Result<Vec<_>>>()?,
            None => statement
                .query_map([], calendar_from_row)?
                .collect::<rusqlite::Result<Vec<_>>>()?,
        };
        Ok(calendars)
    }

    pub fn get_calendar(&self, id: &str) -> Result<Option<Calendar>> {
        let connection = self.connection()?;
        connection
            .query_row(
                r#"
                SELECT id, account_id, remote_id, name, description, color, time_zone, is_primary,
                       read_only, visible, sync_token, created_at, updated_at
                FROM calendars
                WHERE id = ?1
                "#,
                [id],
                calendar_from_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn set_calendar_visible(&self, id: &str, visible: bool) -> Result<bool> {
        let connection = self.connection()?;
        Ok(connection.execute(
            "UPDATE calendars SET visible = ?2, updated_at = ?3 WHERE id = ?1",
            params![id, visible, format_time(Utc::now())],
        )? > 0)
    }

    pub fn get_event(&self, id: &str) -> Result<Option<CalendarEvent>> {
        let connection = self.connection()?;
        connection
            .query_row(
                r#"
                SELECT id, calendar_id, remote_id, uid, etag, title, description, location,
                       start_at, end_at, all_day, status, recurrence_json, raw_payload,
                       created_at, updated_at
                FROM events
                WHERE id = ?1
                "#,
                [id],
                event_from_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn upsert_event(&self, event: &CalendarEvent) -> Result<CalendarEvent> {
        let connection = self.connection()?;
        let existing_id = connection
            .query_row(
                "SELECT id FROM events WHERE calendar_id = ?1 AND remote_id = ?2",
                params![event.calendar_id, event.remote_id],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        let mut stored = event.clone();
        if let Some(existing_id) = existing_id {
            stored.id = existing_id;
        }
        connection.execute(
            r#"
            INSERT INTO events(
                id, calendar_id, remote_id, uid, etag, title, description, location,
                start_at, end_at, all_day, status, recurrence_json, raw_payload,
                created_at, updated_at
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16
            )
            ON CONFLICT(calendar_id, remote_id) DO UPDATE SET
                uid = excluded.uid,
                etag = excluded.etag,
                title = excluded.title,
                description = excluded.description,
                location = excluded.location,
                start_at = excluded.start_at,
                end_at = excluded.end_at,
                all_day = excluded.all_day,
                status = excluded.status,
                recurrence_json = excluded.recurrence_json,
                raw_payload = excluded.raw_payload,
                updated_at = excluded.updated_at
            "#,
            params![
                stored.id,
                stored.calendar_id,
                stored.remote_id,
                stored.uid,
                stored.etag,
                stored.title,
                stored.description,
                stored.location,
                format_time(stored.start),
                format_time(stored.end),
                stored.all_day,
                stored.status,
                serde_json::to_string(&stored.recurrence)?,
                stored.raw_payload,
                format_time(stored.created_at),
                format_time(stored.updated_at),
            ],
        )?;
        Ok(stored)
    }

    pub fn delete_event(&self, id: &str) -> Result<bool> {
        let connection = self.connection()?;
        Ok(connection.execute("DELETE FROM events WHERE id = ?1", [id])? > 0)
    }

    pub fn clear_calendar_sync_token(&self, id: &str) -> Result<()> {
        let connection = self.connection()?;
        connection.execute(
            "UPDATE calendars SET sync_token = '', updated_at = ?2 WHERE id = ?1",
            params![id, format_time(Utc::now())],
        )?;
        Ok(())
    }

    pub fn sync_window_covers(
        &self,
        calendar_id: &str,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<bool> {
        let connection = self.connection()?;
        let window = connection
            .query_row(
                "SELECT window_start, window_end FROM sync_state WHERE calendar_id = ?1",
                [calendar_id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
            )
            .optional()?;
        let Some((stored_start, stored_end)) = window else {
            return Ok(false);
        };
        let (Ok(stored_start), Ok(stored_end)) =
            (parse_time(&stored_start), parse_time(&stored_end))
        else {
            return Ok(false);
        };
        Ok(stored_start <= start && stored_end >= end)
    }

    pub fn prune_events_before(&self, calendar_id: &str, cutoff: DateTime<Utc>) -> Result<usize> {
        let connection = self.connection()?;
        Ok(connection.execute(
            "DELETE FROM events WHERE calendar_id = ?1 AND end_at < ?2",
            params![calendar_id, format_time(cutoff)],
        )?)
    }

    pub fn apply_sync_batch(
        &self,
        calendar: &Calendar,
        batch: &SyncBatch,
        window_start: DateTime<Utc>,
        window_end: DateTime<Utc>,
    ) -> Result<()> {
        let mut connection = self.connection()?;
        let transaction = connection.transaction()?;
        let now = format_time(Utc::now());
        let mut snapshot_ids = HashSet::new();

        for change in &batch.changes {
            match change {
                EventChange::Upsert(event) => {
                    snapshot_ids.insert(event.remote_id.clone());
                    transaction.execute(
                        r#"
                        INSERT INTO events(
                            id, calendar_id, remote_id, uid, etag, title, description, location,
                            start_at, end_at, all_day, status, recurrence_json, raw_payload,
                            created_at, updated_at
                        ) VALUES (
                            ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                            ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16
                        )
                        ON CONFLICT(calendar_id, remote_id) DO UPDATE SET
                            uid = excluded.uid,
                            etag = excluded.etag,
                            title = excluded.title,
                            description = excluded.description,
                            location = excluded.location,
                            start_at = excluded.start_at,
                            end_at = excluded.end_at,
                            all_day = excluded.all_day,
                            status = excluded.status,
                            recurrence_json = excluded.recurrence_json,
                            raw_payload = excluded.raw_payload,
                            updated_at = excluded.updated_at
                        "#,
                        params![
                            event.id,
                            calendar.id,
                            event.remote_id,
                            event.uid,
                            event.etag,
                            event.title,
                            event.description,
                            event.location,
                            format_time(event.start),
                            format_time(event.end),
                            event.all_day,
                            event.status,
                            serde_json::to_string(&event.recurrence)?,
                            event.raw_payload,
                            format_time(event.created_at),
                            format_time(event.updated_at),
                        ],
                    )?;
                }
                EventChange::Delete { remote_id } => {
                    transaction.execute(
                        "DELETE FROM events WHERE calendar_id = ?1 AND remote_id = ?2",
                        params![calendar.id, remote_id],
                    )?;
                }
            }
        }

        if batch.full_snapshot {
            let mut statement = transaction.prepare(
                r#"
                SELECT remote_id
                FROM events
                WHERE calendar_id = ?1 AND end_at >= ?2 AND start_at <= ?3
                "#,
            )?;
            let existing = statement
                .query_map(
                    params![
                        calendar.id,
                        format_time(window_start),
                        format_time(window_end)
                    ],
                    |row| row.get::<_, String>(0),
                )?
                .collect::<rusqlite::Result<Vec<_>>>()?;
            drop(statement);
            for remote_id in existing {
                if !snapshot_ids.contains(&remote_id) {
                    transaction.execute(
                        "DELETE FROM events WHERE calendar_id = ?1 AND remote_id = ?2",
                        params![calendar.id, remote_id],
                    )?;
                }
            }
        }

        transaction.execute(
            "UPDATE calendars SET sync_token = ?2, updated_at = ?3 WHERE id = ?1",
            params![calendar.id, batch.next_token, now],
        )?;
        transaction.execute(
            r#"
            INSERT INTO sync_state(
                calendar_id, window_start, window_end, last_full_sync_at, last_incremental_sync_at
            ) VALUES (?1, ?2, ?3, ?4, ?5)
            ON CONFLICT(calendar_id) DO UPDATE SET
                window_start = CASE
                    WHEN excluded.last_full_sync_at IS NOT NULL THEN excluded.window_start
                    ELSE sync_state.window_start
                END,
                window_end = CASE
                    WHEN excluded.last_full_sync_at IS NOT NULL THEN excluded.window_end
                    ELSE sync_state.window_end
                END,
                last_full_sync_at = COALESCE(
                    excluded.last_full_sync_at,
                    sync_state.last_full_sync_at
                ),
                last_incremental_sync_at = excluded.last_incremental_sync_at
            "#,
            params![
                calendar.id,
                format_time(window_start),
                format_time(window_end),
                batch.full_snapshot.then(|| now.clone()),
                now,
            ],
        )?;

        transaction.commit()?;
        Ok(())
    }

    pub fn list_events(
        &self,
        from: DateTime<Utc>,
        to: DateTime<Utc>,
        calendar_id: Option<&str>,
        visible_only: bool,
    ) -> Result<Vec<CalendarEvent>> {
        let connection = self.connection()?;
        let mut conditions = vec!["events.end_at >= ?1", "events.start_at <= ?2"];
        if calendar_id.is_some() {
            conditions.push("events.calendar_id = ?3");
        }
        if visible_only {
            conditions.push("calendars.visible = 1");
        }
        let sql = format!(
            r#"
            SELECT events.id, events.calendar_id, events.remote_id, events.uid, events.etag,
                   events.title, events.description, events.location, events.start_at,
                   events.end_at, events.all_day, events.status, events.recurrence_json,
                   events.raw_payload, events.created_at, events.updated_at
            FROM events
            JOIN calendars ON calendars.id = events.calendar_id
            WHERE {}
            ORDER BY events.start_at, events.end_at
            "#,
            conditions.join(" AND ")
        );
        let mut statement = connection.prepare(&sql)?;
        let from = format_time(from);
        let to = format_time(to);
        let events = match calendar_id {
            Some(calendar_id) => statement
                .query_map(params![from, to, calendar_id], event_from_row)?
                .collect::<rusqlite::Result<Vec<_>>>()?,
            None => statement
                .query_map(params![from, to], event_from_row)?
                .collect::<rusqlite::Result<Vec<_>>>()?,
        };
        Ok(events)
    }

    pub fn pending_event_reminders(
        &self,
        now: DateTime<Utc>,
        reminder_cutoff: DateTime<Utc>,
    ) -> Result<Vec<CalendarEvent>> {
        let connection = self.connection()?;
        let mut statement = connection.prepare(
            r#"
            SELECT events.id, events.calendar_id, events.remote_id, events.uid, events.etag,
                   events.title, events.description, events.location, events.start_at,
                   events.end_at, events.all_day, events.status, events.recurrence_json,
                   events.raw_payload, events.created_at, events.updated_at
            FROM events
            JOIN calendars ON calendars.id = events.calendar_id
            JOIN accounts ON accounts.id = calendars.account_id
            WHERE accounts.enabled = 1
              AND events.all_day = 0
              AND LOWER(events.status) NOT IN ('cancelled', 'canceled')
              AND events.start_at > ?1
              AND events.start_at <= ?2
              AND NOT EXISTS (
                  SELECT 1
                  FROM event_reminders
                  WHERE event_reminders.event_id = events.id
                    AND event_reminders.event_start_at = events.start_at
              )
            ORDER BY events.start_at, events.end_at
            "#,
        )?;
        let rows = statement.query_map(
            params![format_time(now), format_time(reminder_cutoff)],
            event_from_row,
        )?;
        rows.collect::<rusqlite::Result<Vec<_>>>()
            .map_err(Into::into)
    }

    pub fn mark_event_reminder_sent(
        &self,
        event_id: &str,
        event_start: DateTime<Utc>,
        notified_at: DateTime<Utc>,
    ) -> Result<()> {
        let connection = self.connection()?;
        connection.execute(
            r#"
            INSERT OR IGNORE INTO event_reminders(event_id, event_start_at, notified_at)
            VALUES (?1, ?2, ?3)
            "#,
            params![event_id, format_time(event_start), format_time(notified_at)],
        )?;
        Ok(())
    }

    pub fn prune_event_reminders_before(&self, cutoff: DateTime<Utc>) -> Result<usize> {
        let connection = self.connection()?;
        Ok(connection.execute(
            "DELETE FROM event_reminders WHERE event_start_at < ?1",
            [format_time(cutoff)],
        )?)
    }

    pub fn counts(&self) -> Result<(u64, u64, u64)> {
        let connection = self.connection()?;
        let accounts: i64 =
            connection.query_row("SELECT COUNT(*) FROM accounts", [], |row| row.get(0))?;
        let calendars: i64 =
            connection.query_row("SELECT COUNT(*) FROM calendars", [], |row| row.get(0))?;
        let events: i64 =
            connection.query_row("SELECT COUNT(*) FROM events", [], |row| row.get(0))?;
        Ok((
            accounts.try_into().context("account count was negative")?,
            calendars
                .try_into()
                .context("calendar count was negative")?,
            events.try_into().context("event count was negative")?,
        ))
    }
}

fn account_from_row(row: &Row<'_>) -> rusqlite::Result<Account> {
    let provider: String = row.get(1)?;
    let config: String = row.get(4)?;
    let last_sync: Option<String> = row.get(8)?;
    Ok(Account {
        id: row.get(0)?,
        provider: ProviderKind::from_str(&provider).map_err(to_sql_error)?,
        display_name: row.get(2)?,
        email: row.get(3)?,
        config: serde_json::from_str(&config).map_err(to_sql_error)?,
        enabled: row.get(5)?,
        needs_reauth: row.get(6)?,
        last_error: row.get(7)?,
        last_sync_at: last_sync
            .map(|value| parse_time(&value))
            .transpose()
            .map_err(to_sql_error)?,
        created_at: parse_time(&row.get::<_, String>(9)?).map_err(to_sql_error)?,
        updated_at: parse_time(&row.get::<_, String>(10)?).map_err(to_sql_error)?,
    })
}

fn calendar_from_row(row: &Row<'_>) -> rusqlite::Result<Calendar> {
    Ok(Calendar {
        id: row.get(0)?,
        account_id: row.get(1)?,
        remote_id: row.get(2)?,
        name: row.get(3)?,
        description: row.get(4)?,
        color: row.get(5)?,
        time_zone: row.get(6)?,
        primary: row.get(7)?,
        read_only: row.get(8)?,
        visible: row.get(9)?,
        sync_token: row.get(10)?,
        created_at: parse_time(&row.get::<_, String>(11)?).map_err(to_sql_error)?,
        updated_at: parse_time(&row.get::<_, String>(12)?).map_err(to_sql_error)?,
    })
}

fn event_from_row(row: &Row<'_>) -> rusqlite::Result<CalendarEvent> {
    let recurrence: String = row.get(12)?;
    Ok(CalendarEvent {
        id: row.get(0)?,
        calendar_id: row.get(1)?,
        remote_id: row.get(2)?,
        uid: row.get(3)?,
        etag: row.get(4)?,
        title: row.get(5)?,
        description: row.get(6)?,
        location: row.get(7)?,
        start: parse_time(&row.get::<_, String>(8)?).map_err(to_sql_error)?,
        end: parse_time(&row.get::<_, String>(9)?).map_err(to_sql_error)?,
        all_day: row.get(10)?,
        status: row.get(11)?,
        recurrence: serde_json::from_str(&recurrence).map_err(to_sql_error)?,
        raw_payload: row.get(13)?,
        created_at: parse_time(&row.get::<_, String>(14)?).map_err(to_sql_error)?,
        updated_at: parse_time(&row.get::<_, String>(15)?).map_err(to_sql_error)?,
    })
}

fn format_time(time: DateTime<Utc>) -> String {
    time.to_rfc3339_opts(chrono::SecondsFormat::Millis, true)
}

fn parse_time(value: &str) -> std::result::Result<DateTime<Utc>, chrono::ParseError> {
    Ok(DateTime::parse_from_rfc3339(value)?.with_timezone(&Utc))
}

fn to_sql_error(error: impl std::fmt::Display) -> rusqlite::Error {
    rusqlite::Error::FromSqlConversionFailure(
        0,
        rusqlite::types::Type::Text,
        Box::new(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            error.to_string(),
        )),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn test_database() -> (Database, std::path::PathBuf) {
        let path = std::env::temp_dir().join(format!("calendar-db-test-{}.db", Uuid::new_v4()));
        (Database::open(&path).expect("open test database"), path)
    }

    fn account() -> Account {
        let now = Utc::now();
        Account {
            id: "google:test".to_string(),
            provider: ProviderKind::Google,
            display_name: "Test".to_string(),
            email: "test@example.com".to_string(),
            config: json!({"clientId": "test"}),
            enabled: true,
            needs_reauth: false,
            last_error: String::new(),
            last_sync_at: None,
            created_at: now,
            updated_at: now,
        }
    }

    #[test]
    fn stores_accounts_calendars_and_events() {
        let (database, path) = test_database();
        database.upsert_account(&account()).expect("store account");
        let calendars = database
            .reconcile_calendars(
                "google:test",
                &[RemoteCalendar {
                    remote_id: "primary".to_string(),
                    name: "Primary".to_string(),
                    description: String::new(),
                    color: "#4285f4".to_string(),
                    time_zone: "UTC".to_string(),
                    primary: true,
                    read_only: false,
                }],
            )
            .expect("store calendar");
        let now = Utc::now();
        let event = CalendarEvent {
            id: Uuid::new_v4().to_string(),
            calendar_id: calendars[0].id.clone(),
            remote_id: "event-1".to_string(),
            uid: "event-1@example.com".to_string(),
            etag: "etag".to_string(),
            title: "Meeting".to_string(),
            description: String::new(),
            location: String::new(),
            start: now + chrono::Duration::minutes(10),
            end: now + chrono::Duration::hours(1),
            all_day: false,
            status: "confirmed".to_string(),
            recurrence: Vec::new(),
            raw_payload: String::new(),
            created_at: now,
            updated_at: now,
        };
        let event_id = event.id.clone();
        database
            .apply_sync_batch(
                &calendars[0],
                &SyncBatch {
                    changes: vec![EventChange::Upsert(Box::new(event))],
                    next_token: "next".to_string(),
                    full_snapshot: true,
                },
                now - chrono::Duration::days(1),
                now + chrono::Duration::days(1),
            )
            .expect("apply sync");

        assert_eq!(database.counts().expect("counts"), (1, 1, 1));
        let mut stored_event = database
            .get_event(&event_id)
            .expect("read event")
            .expect("stored event exists");
        stored_event.title = "Updated meeting".to_string();
        let updated_event = database.upsert_event(&stored_event).expect("update event");
        assert_eq!(updated_event.id, event_id);
        assert_eq!(
            database
                .get_event(&event_id)
                .expect("read updated event")
                .expect("updated event exists")
                .title,
            "Updated meeting"
        );
        assert!(calendars[0].primary);
        assert!(
            database
                .sync_window_covers(
                    &calendars[0].id,
                    now - chrono::Duration::hours(12),
                    now + chrono::Duration::hours(12),
                )
                .expect("read sync window")
        );
        assert!(
            !database
                .sync_window_covers(
                    &calendars[0].id,
                    now - chrono::Duration::days(2),
                    now + chrono::Duration::days(2),
                )
                .expect("read sync window")
        );
        assert_eq!(
            database
                .prune_events_before(&calendars[0].id, now - chrono::Duration::days(1))
                .expect("prune retained event"),
            0
        );
        assert_eq!(
            database
                .list_events(
                    now - chrono::Duration::days(1),
                    now + chrono::Duration::days(1),
                    None,
                    true,
                )
                .expect("list events")
                .len(),
            1
        );
        let reminders = database
            .pending_event_reminders(now, now + chrono::Duration::minutes(30))
            .expect("list pending reminders");
        assert_eq!(reminders.len(), 1);
        database
            .mark_event_reminder_sent(&event_id, reminders[0].start, now)
            .expect("mark reminder sent");
        assert!(
            database
                .pending_event_reminders(now, now + chrono::Duration::minutes(30))
                .expect("list reminders after marking")
                .is_empty()
        );
        assert!(database.delete_event(&event_id).expect("delete event"));
        assert!(
            database
                .get_event(&event_id)
                .expect("read deletion")
                .is_none()
        );

        drop(database);
        fs::remove_file(path).ok();
    }
}
