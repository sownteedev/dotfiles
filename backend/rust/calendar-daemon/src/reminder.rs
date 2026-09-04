use crate::database::Database;
use crate::model::CalendarEvent;
use anyhow::{Context, Result, bail};
use chrono::{Duration as ChronoDuration, Local, Utc};
use std::process::Stdio;
use std::time::Duration;
use tokio::process::Command;
use tokio::sync::watch;
use tokio::time::{MissedTickBehavior, interval, timeout};

const POLL_INTERVAL: Duration = Duration::from_secs(15);
const REMINDER_LEAD_MINUTES: i64 = 30;
const REMINDER_RETENTION_DAYS: i64 = 7;

pub struct ReminderScheduler {
    database: Database,
}

impl ReminderScheduler {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub async fn run(self, mut shutdown: watch::Receiver<bool>) {
        let mut timer = interval(POLL_INTERVAL);
        timer.set_missed_tick_behavior(MissedTickBehavior::Skip);

        loop {
            tokio::select! {
                changed = shutdown.changed() => {
                    if changed.is_err() || *shutdown.borrow() {
                        break;
                    }
                }
                _ = timer.tick() => {
                    if let Err(error) = self.check_due_events().await {
                        eprintln!("calendar reminder check failed: {error:#}");
                    }
                }
            }
        }
    }

    async fn check_due_events(&self) -> Result<()> {
        let now = Utc::now();
        let cutoff = now + ChronoDuration::minutes(REMINDER_LEAD_MINUTES);
        let events = self
            .database
            .pending_event_reminders(now, cutoff)
            .context("query upcoming calendar reminders")?;

        for event in events {
            self.send_notification(&event).await?;
            self.database
                .mark_event_reminder_sent(&event.id, event.start, Utc::now())
                .with_context(|| format!("record reminder for calendar event {}", event.id))?;
        }

        self.database
            .prune_event_reminders_before(now - ChronoDuration::days(REMINDER_RETENTION_DAYS))
            .context("prune old calendar reminders")?;
        Ok(())
    }

    async fn send_notification(&self, event: &CalendarEvent) -> Result<()> {
        let title = if event.title.trim().is_empty() {
            "Calendar event"
        } else {
            event.title.trim()
        };
        let local_start = event.start.with_timezone(&Local);
        let mut body = format!(
            "Starts in {REMINDER_LEAD_MINUTES} minutes · {}",
            local_start.format("%H:%M")
        );
        if !event.location.trim().is_empty() {
            body.push('\n');
            body.push_str(event.location.trim());
        }

        let status = timeout(
            Duration::from_secs(5),
            Command::new("notify-send")
                .args([
                    "-a",
                    "SownteeShell Calendar",
                    "-u",
                    "critical",
                    "-i",
                    "x-office-calendar-symbolic",
                    "--",
                    title,
                    &body,
                ])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status(),
        )
        .await
        .context("calendar notification timed out")?
        .context("launch notify-send for calendar reminder")?;
        if !status.success() {
            bail!("notify-send exited with {status}");
        }
        Ok(())
    }
}
