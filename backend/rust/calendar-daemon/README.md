# SownteeShell Calendar backend

Standalone backend for SownteeShell Calendar. The Quickshell Calendar uses it as one persistent process;
the existing Google Tasks/Todo flow remains on `GoogleService.qml`.

## Current scope

- Google Calendar OAuth PKCE, calendar discovery, event CRUD, and incremental `syncToken` updates.
- Microsoft Calendar OAuth PKCE, event CRUD, default-calendar delta sync, and bounded sync for other
  calendars.
- iCloud Calendar discovery, bounded event sync, and event CRUD through CalDAV with an app-specific
  password.
- SQLite cache, one sync scheduler, 30-minute critical event reminders, Secret Service credential
  storage, and Unix-socket JSON Lines IPC.
- Provider-neutral accounts, calendars, and events are combined by `CalendarService.qml`; visibility
  can be filtered per account or per calendar without splitting the timeline.

## Build and validate

```sh
cargo build --manifest-path quickshell/backend/rust/calendar-daemon/Cargo.toml
cargo test --manifest-path quickshell/backend/rust/calendar-daemon/Cargo.toml
cargo clippy --manifest-path quickshell/backend/rust/calendar-daemon/Cargo.toml --all-targets -- -D warnings
```

## Commands

```sh
sownteeshell-calendar-daemon serve
sownteeshell-calendar-daemon check
sownteeshell-calendar-daemon paths
sownteeshell-calendar-daemon sync-once [account-id]
sownteeshell-calendar-daemon request <method> '<params-json>'
```

The daemon runs an immediate sync pass, then repeats at the configured interval. `SIGTERM` and
`Ctrl-C` stop the scheduler, connected clients, and Unix socket cleanly.

## IPC

Each request and response is one JSON object followed by a newline:

```json
{
    "id": "1",
    "method": "events.list",
    "params": { "from": "2026-09-01T00:00:00Z", "to": "2026-10-01T00:00:00Z" }
}
```

Supported methods:

- `ping`, `system.info`
- `accounts.list`, `accounts.setEnabled`, `accounts.remove`
- `accounts.google.add`, `accounts.microsoft.add`, `accounts.icloud.add`
- `calendars.list`, `calendars.setVisible`
- `events.list`, `events.create`, `events.update`, `events.delete`, `sync.now`
- `subscribe` with optional `topics` such as `accounts`, `calendars`, `events`, and `sync`

Account credentials must be sent by a trusted local client over the private socket. Avoid putting
passwords or OAuth client secrets directly in shell history.

## Configuration

| Variable                                 | Default               |
| ---------------------------------------- | --------------------- |
| `SOWNTEE_CALENDAR_SYNC_INTERVAL_SECONDS` | `900`                 |
| `SOWNTEE_CALENDAR_SYNC_PAST_DAYS`        | `90`                  |
| `SOWNTEE_CALENDAR_SYNC_FUTURE_DAYS`      | `365`                 |
| `SOWNTEE_CALENDAR_GOOGLE_CLIENT_ID`      | unset                 |
| `SOWNTEE_CALENDAR_GOOGLE_CLIENT_SECRET`  | unset                 |
| `SOWNTEE_CALENDAR_MICROSOFT_CLIENT_ID`   | unset                 |
| `SOWNTEE_CALENDAR_MICROSOFT_TENANT`      | `common`              |
| `SOWNTEE_CALENDAR_DB`                    | XDG data directory    |
| `SOWNTEE_CALENDAR_SOCKET`                | XDG runtime directory |

The database is created with mode `0600`; its data and runtime directories use `0700`. OAuth
tokens, optional Google client secrets, and CalDAV passwords are stored only in Secret Service.

Google accounts created with the old read-only OAuth scope and Microsoft accounts created with
`Calendars.Read` must be connected again once so the provider grants write access.
