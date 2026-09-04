use crate::config::Config;
use crate::database::Database;
use crate::model::{Account, AccountSyncReport, DaemonEvent, ProviderKind, SyncReport};
use crate::providers::{ProviderError, ProviderRegistry, ProviderResult, SyncWindow};
use anyhow::{Context, Result, anyhow};
use chrono::{Duration, TimeZone, Utc};
use std::sync::Arc;
use tokio::sync::{Mutex, broadcast};

const FULL_SYNC_PADDING_DAYS: i64 = 14;

#[derive(Clone)]
pub struct SyncService {
    database: Database,
    providers: ProviderRegistry,
    past_days: i64,
    future_days: i64,
    lock: Arc<Mutex<()>>,
    events: broadcast::Sender<DaemonEvent>,
}

impl SyncService {
    pub fn new(
        database: Database,
        providers: ProviderRegistry,
        config: &Config,
        events: broadcast::Sender<DaemonEvent>,
    ) -> Self {
        Self {
            database,
            providers,
            past_days: config.sync_past_days,
            future_days: config.sync_future_days,
            lock: Arc::new(Mutex::new(())),
            events,
        }
    }

    pub async fn sync_all(&self) -> Result<SyncReport> {
        let _guard = self.lock.lock().await;
        let accounts = self
            .database
            .list_accounts(true)
            .context("list enabled calendar accounts")?;
        let mut report = SyncReport::default();
        for account in accounts {
            if account.needs_reauth {
                report.accounts.push(AccountSyncReport {
                    account_id: account.id,
                    success: false,
                    calendars_synced: 0,
                    error: Some("reauthentication required".to_string()),
                });
                continue;
            }
            report.accounts.push(self.sync_one(&account).await);
        }
        Ok(report)
    }

    pub async fn sync_account(&self, account_id: &str) -> Result<AccountSyncReport> {
        let _guard = self.lock.lock().await;
        let account = self
            .database
            .get_account(account_id)?
            .ok_or_else(|| anyhow!("calendar account not found: {account_id}"))?;
        Ok(self.sync_one(&account).await)
    }

    async fn sync_one(&self, account: &Account) -> AccountSyncReport {
        self.publish(DaemonEvent::sync("started", &account.id, None));
        match self.sync_one_inner(account).await {
            Ok(calendars_synced) => {
                if let Err(error) = self.database.set_account_sync_success(&account.id) {
                    return self.failed_report(account, error.into(), false);
                }
                self.publish(DaemonEvent::sync("completed", &account.id, None));
                AccountSyncReport {
                    account_id: account.id.clone(),
                    success: true,
                    calendars_synced,
                    error: None,
                }
            }
            Err(error) => {
                let needs_reauth = matches!(error, ProviderError::Reauth(_));
                self.failed_report(account, error, needs_reauth)
            }
        }
    }

    async fn sync_one_inner(&self, account: &Account) -> ProviderResult<usize> {
        let provider = self.providers.get(account.provider);
        debug_assert_eq!(provider.kind(), account.provider);

        let remote_calendars = provider.list_calendars(account).await?;
        let calendars = self
            .database
            .reconcile_calendars(&account.id, &remote_calendars)?;
        let today = Utc::now().date_naive();
        let midnight = Utc.from_utc_datetime(
            &today
                .and_hms_opt(0, 0, 0)
                .expect("midnight is always a valid time"),
        );
        let desired_window = SyncWindow {
            start: midnight - Duration::days(self.past_days),
            end: midnight + Duration::days(self.future_days + 1),
        };
        let full_window = SyncWindow {
            start: desired_window.start - Duration::days(FULL_SYNC_PADDING_DAYS),
            end: desired_window.end + Duration::days(FULL_SYNC_PADDING_DAYS),
        };

        let mut synced = 0;
        for mut calendar in calendars {
            let supports_cursor = account.provider == ProviderKind::Google
                || (account.provider == ProviderKind::Microsoft && calendar.primary);
            let window = if supports_cursor
                && (calendar.sync_token.is_empty()
                    || !self.database.sync_window_covers(
                        &calendar.id,
                        desired_window.start,
                        desired_window.end,
                    )?) {
                if !calendar.sync_token.is_empty() {
                    self.database.clear_calendar_sync_token(&calendar.id)?;
                    calendar.sync_token.clear();
                }
                full_window
            } else {
                desired_window
            };

            let batch = match provider.sync_calendar(account, &calendar, window).await {
                Err(ProviderError::CursorExpired(_)) => {
                    self.database.clear_calendar_sync_token(&calendar.id)?;
                    let mut fresh_calendar = calendar.clone();
                    fresh_calendar.sync_token.clear();
                    provider
                        .sync_calendar(account, &fresh_calendar, full_window)
                        .await?
                }
                result => result?,
            };
            let applied_window = if batch.full_snapshot && supports_cursor {
                full_window
            } else {
                window
            };
            self.database.apply_sync_batch(
                &calendar,
                &batch,
                applied_window.start,
                applied_window.end,
            )?;
            if account.provider != ProviderKind::CalDav {
                self.database
                    .prune_events_before(&calendar.id, desired_window.start)?;
            }
            synced += 1;
            self.publish(DaemonEvent::changed(
                "events",
                Some(&account.id),
                Some(&calendar.id),
            ));
        }
        self.publish(DaemonEvent::changed("calendars", Some(&account.id), None));
        Ok(synced)
    }

    fn failed_report(
        &self,
        account: &Account,
        error: ProviderError,
        needs_reauth: bool,
    ) -> AccountSyncReport {
        let message = error.to_string();
        if let Err(database_error) =
            self.database
                .set_account_sync_error(&account.id, &message, needs_reauth)
        {
            eprintln!(
                "failed to store sync error for account {}: {database_error:#}",
                account.id
            );
        }
        self.publish(DaemonEvent::sync(
            "failed",
            &account.id,
            Some(message.clone()),
        ));
        AccountSyncReport {
            account_id: account.id.clone(),
            success: false,
            calendars_synced: 0,
            error: Some(message),
        }
    }

    fn publish(&self, event: DaemonEvent) {
        let _ = self.events.send(event);
    }
}
