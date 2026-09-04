use crate::sync::SyncService;
use std::time::Duration;
use tokio::sync::watch;
use tokio::time::{MissedTickBehavior, interval_at};

pub struct Scheduler {
    sync: SyncService,
    interval: Duration,
}

impl Scheduler {
    pub fn new(sync: SyncService, interval: Duration) -> Self {
        Self { sync, interval }
    }

    pub async fn run(self, mut shutdown: watch::Receiver<bool>) {
        if self.sync_or_shutdown(&mut shutdown).await {
            return;
        }

        let start = tokio::time::Instant::now() + self.interval;
        let mut timer = interval_at(start, self.interval);
        timer.set_missed_tick_behavior(MissedTickBehavior::Skip);

        loop {
            tokio::select! {
                changed = shutdown.changed() => {
                    if changed.is_err() || *shutdown.borrow() {
                        break;
                    }
                }
                _ = timer.tick() => {
                    if self.sync_or_shutdown(&mut shutdown).await {
                        break;
                    }
                }
            }
        }
    }

    async fn sync_or_shutdown(&self, shutdown: &mut watch::Receiver<bool>) -> bool {
        tokio::select! {
            changed = shutdown.changed() => changed.is_err() || *shutdown.borrow(),
            result = self.sync.sync_all() => {
                match result {
                    Ok(report) if report.failed() > 0 => eprintln!(
                        "calendar sync completed with {} failed account(s)",
                        report.failed()
                    ),
                    Err(error) => eprintln!("calendar scheduler failed: {error:#}"),
                    _ => {}
                }
                false
            }
        }
    }
}
