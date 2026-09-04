PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL CHECK (provider IN ('google', 'microsoft', 'caldav')),
    display_name TEXT NOT NULL,
    email TEXT NOT NULL DEFAULT '',
    config_json TEXT NOT NULL DEFAULT '{}',
    enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
    needs_reauth INTEGER NOT NULL DEFAULT 0 CHECK (needs_reauth IN (0, 1)),
    last_error TEXT NOT NULL DEFAULT '',
    last_sync_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS calendars (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    remote_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    color TEXT NOT NULL DEFAULT '',
    time_zone TEXT NOT NULL DEFAULT '',
    is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
    read_only INTEGER NOT NULL DEFAULT 0 CHECK (read_only IN (0, 1)),
    visible INTEGER NOT NULL DEFAULT 1 CHECK (visible IN (0, 1)),
    sync_token TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (account_id, remote_id)
);

CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    calendar_id TEXT NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
    remote_id TEXT NOT NULL,
    uid TEXT NOT NULL DEFAULT '',
    etag TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    location TEXT NOT NULL DEFAULT '',
    start_at TEXT NOT NULL,
    end_at TEXT NOT NULL,
    all_day INTEGER NOT NULL DEFAULT 0 CHECK (all_day IN (0, 1)),
    status TEXT NOT NULL DEFAULT 'confirmed',
    recurrence_json TEXT NOT NULL DEFAULT '[]',
    raw_payload TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (calendar_id, remote_id)
);

CREATE TABLE IF NOT EXISTS sync_state (
    calendar_id TEXT PRIMARY KEY REFERENCES calendars(id) ON DELETE CASCADE,
    window_start TEXT NOT NULL DEFAULT '',
    window_end TEXT NOT NULL DEFAULT '',
    last_full_sync_at TEXT,
    last_incremental_sync_at TEXT,
    retry_after TEXT
);

CREATE INDEX IF NOT EXISTS idx_accounts_provider ON accounts(provider);
CREATE INDEX IF NOT EXISTS idx_calendars_account ON calendars(account_id);
CREATE INDEX IF NOT EXISTS idx_events_calendar_start ON events(calendar_id, start_at);
CREATE INDEX IF NOT EXISTS idx_events_start_end ON events(start_at, end_at);
CREATE INDEX IF NOT EXISTS idx_events_uid ON events(uid);

INSERT OR IGNORE INTO schema_migrations(version, applied_at)
VALUES (1, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));
