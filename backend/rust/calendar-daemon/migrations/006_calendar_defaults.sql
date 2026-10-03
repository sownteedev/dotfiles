BEGIN;
ALTER TABLE calendars ADD COLUMN default_reminder_minutes INTEGER;

INSERT OR IGNORE INTO schema_migrations(version, applied_at)
VALUES (6, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));
COMMIT;
