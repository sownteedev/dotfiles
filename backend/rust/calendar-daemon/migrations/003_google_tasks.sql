CREATE TABLE IF NOT EXISTS google_tasks (
    account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    visible INTEGER NOT NULL DEFAULT 1,
    snapshot_json TEXT NOT NULL DEFAULT '[]',
    lists_json TEXT NOT NULL DEFAULT '[]',
    default_list_id TEXT NOT NULL DEFAULT '',
    last_error TEXT NOT NULL DEFAULT '',
    updated_at TEXT
);
