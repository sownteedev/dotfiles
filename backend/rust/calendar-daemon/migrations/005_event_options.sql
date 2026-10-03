ALTER TABLE events ADD COLUMN preferences_json TEXT NOT NULL DEFAULT '{}';
UPDATE events SET preferences_json = json_object('localReminders', json_array(local_reminder_minutes))
WHERE local_reminder_minutes IS NOT NULL;

CREATE TABLE event_reminder_deliveries (
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    event_start_at TEXT NOT NULL,
    reminder_minutes INTEGER NOT NULL,
    notified_at TEXT NOT NULL,
    PRIMARY KEY (event_id, event_start_at, reminder_minutes)
);
INSERT OR IGNORE INTO event_reminder_deliveries
SELECT r.event_id, r.event_start_at, e.local_reminder_minutes, r.notified_at
FROM event_reminders r JOIN events e ON e.id = r.event_id
WHERE e.local_reminder_minutes IS NOT NULL;
INSERT INTO schema_migrations(version, applied_at)
VALUES (5, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));
