PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS event_reminders (
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    event_start_at TEXT NOT NULL,
    notified_at TEXT NOT NULL,
    PRIMARY KEY (event_id, event_start_at)
);

CREATE INDEX IF NOT EXISTS idx_event_reminders_notified_at
ON event_reminders(notified_at);

INSERT OR IGNORE INTO schema_migrations(version, applied_at)
VALUES (2, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));
