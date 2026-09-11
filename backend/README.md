# SownteeShell backend

This directory contains the non-visual implementation used by SownteeShell.
QML owns presentation and short-lived UI state; backend code owns blocking,
privileged, stateful, or performance-sensitive work.

## Layout

```text
backend/
├── cli/
│   └── sownteeshell       # User-facing IPC command
├── native/
│   └── bluetooth/          # Small Qt/C++ hardware helpers
├── python/
│   ├── auth/               # Privileged Howdy integration
│   ├── capture/            # Screenshot composition
│   ├── launcher/           # Generated Emoji/Unicode catalog data
│   └── portal/             # XDG desktop portal file picker
├── rust/
│   ├── core-daemon/        # Shared shell and system backend
│   └── calendar-daemon/    # Calendar accounts, events, and synchronization
└── systemd/user/           # User units for both Rust daemons
```

Python and native helpers are invoked on demand. The two Rust backends are
long-running user services and communicate with QML through private Unix
sockets using newline-delimited JSON.

## Core daemon

`rust/core-daemon` provides the shared backend for:

- system, process, battery, charging, application, and package telemetry;
- clipboard history, persistent favorites and restoration, diagnostics, updates,
  Wi-Fi QR generation, and display integration for Niri, DDC/CI, and Sunshine;
- transactional Niri and SownteeShell settings, synchronized GTK 3/4 and Qt 5/6
  appearance (`settings.gtk.apply`, `settings.general.apply`: application themes, icons,
  cursor theme & size synchronized with Niri, interface typography, Kvantum/Fusion widget styles,
  color schemes, standard dialogs, and XSettings broadcast), and greetd profile, session,
  background, and palette synchronization;
- Weather, Emoji/Unicode, KLIPY, Wallhaven, Steam Workshop, Wallpaper Engine,
  preview generation, and bounded media caches.

The default socket is:

```text
$XDG_RUNTIME_DIR/sownteeshell/core/core.sock
```

`CoreService.qml` maintains shared request and subscription sockets. Feature
services use `CoreRequest.qml` for cancellable work, so closing a provider or
starting a newer search can cancel the previous backend job without spawning a
new helper process for every request.

Clipboard favorites are stored by content hash under
`$XDG_DATA_HOME/sownteeshell/core/clipboard/favorites` (default:
`~/.local/share/sownteeshell/core/clipboard/favorites`). Text and clipboard images
survive history cleanup and backend restarts; copied files retain references to
the original files, not backups of those files. Storage is private to the user
(directories `0700`, files `0600`), but is not encrypted. Unpinning removes the
saved copy without deleting clipboard history.

The daemon uses a four-thread Tokio runtime, moves blocking filesystem work off
the async workers, reuses one bounded HTTP client, limits IPC messages to 1 MiB
requests and 16 MiB responses, and applies feature-level limits to downloads,
command output, and caches. Long-running renderers, SteamCMD, FFmpeg,
ImageMagick, Matugen, and privileged system commands remain separate processes
by design.

Run `sownteeshell ipc methods core` for its IPC methods and parameters.

## Calendar daemon

`rust/calendar-daemon` owns calendar accounts, events, and Google Tasks. It supports:

- Google Calendar through OAuth;
- Microsoft Calendar through Microsoft Graph OAuth;
- iCloud Calendar through CalDAV and an app-specific password;
- Google Tasks from all connected Google accounts and task lists, with cached
  snapshots, account-scoped mutations, and shared updates for Todo and Calendar;
- account and calendar visibility, event create/update/delete, iCalendar (`.ics` / `.ical`)
  parsing and batch import (`events.parseIcs`, `events.importIcs`), background
  synchronization, and live change subscriptions;
- local SQLite persistence and deduplicated desktop reminders 30 minutes
  before an event.

Google Tasks uses the Calendar account's OAuth credentials. Existing Google
connections need to grant the additional Tasks scope by reconnecting in Calendar;
Google Tasks API must also be enabled in the OAuth project's Google Cloud console.
The previous Core Tasks backend and separate Tasks sign-in are no longer used.
Local tasks stay on this device and are never uploaded automatically.

`tasks.list` returns per-account cached tasks and lists, including tasks without a
due date. Calendar renders unfinished dated tasks in the all-day lane; Todo keeps
the complete task lists. `tasks.setVisible` only changes Calendar visibility.
Task refresh failures preserve the previous complete snapshot and report a
per-account error without stopping event synchronization. See `sownteeshell ipc
methods calendar` for the task methods and their required account/list identifiers.

The default socket and database are:

```text
$XDG_RUNTIME_DIR/sownteeshell/calendar/calendar.sock
$XDG_DATA_HOME/sownteeshell/calendar/calendar.db
```

OAuth tokens, client secrets, and CalDAV passwords are stored through the
desktop Secret Service rather than in the repository or SQLite database. The
default sync interval is 15 minutes, with a 180-day past window and a 365-day
future window. `events.list` queries default to a 365-day past and 730-day future
window so month and week navigation stays smooth without re-querying. These values can be overridden with:

```text
SOWNTEE_CALENDAR_SYNC_INTERVAL_SECONDS
SOWNTEE_CALENDAR_SYNC_PAST_DAYS
SOWNTEE_CALENDAR_SYNC_FUTURE_DAYS
SOWNTEE_CALENDAR_GOOGLE_CLIENT_ID
SOWNTEE_CALENDAR_GOOGLE_CLIENT_SECRET
SOWNTEE_CALENDAR_MICROSOFT_CLIENT_ID
SOWNTEE_CALENDAR_MICROSOFT_TENANT
```

## One-shot helpers

- `native/bluetooth/airpods_battery_monitor.cpp` reads detailed AirPods left,
  right, case, and charging state over Bluetooth.
- `python/auth/howdy_face_manager.py` is installed as a privileged bridge for
  face-model and camera management.
- `python/capture/screenshot_stitcher.py` composes screenshots without loading
  the full operation into the QML scene.
- `python/portal/file_picker.py` opens the XDG portal picker while preserving
  the owning SownteeShell window lifecycle.
- `python/launcher/generate_unicode_catalog.py` regenerates the Unicode catalog;
  the generated Emoji and Unicode catalogs are searched by the Core daemon.

Shell integrations remain under `../scripts/`, grouped by feature domain.

## Installation and lifecycle

`../../install/.installconfigtheme` builds both Rust backends with their
lockfiles, installs the release binaries under `~/.local/lib/sownteeshell/`,
installs the user units, and enables them for `graphical-session.target`:

```text
sownteeshell-core.service
sownteeshell-calendar.service
```

Both services use `Restart=on-failure`. In a normal installed session, systemd
owns their lifecycle, logs, and cgroups, so reloading or closing Quickshell does
not destroy backend state. The repository runners rebuild stale development
binaries when Cargo is available and expose one-shot compatibility commands.

The installer also provides a unified IPC client at
`~/.local/bin/sownteeshell`:

```sh
sownteeshell ipc call core ping
sownteeshell ipc call core system.info
sownteeshell ipc call calendar accounts.list
sownteeshell ipc methods core
sownteeshell ipc methods calendar
```

An optional JSON object can be supplied as one quoted final argument. The CLI
forwards the request and exit status directly to the selected daemon client.
Run `sownteeshell --help` for the categorized method reference, parameter
fields, safety flags, examples, environment overrides, and exit statuses.

`SOWNTEE_CORE_SOCKET` and `SOWNTEE_CALENDAR_SOCKET` override the socket paths for
isolated development or tests without attaching to the active user services.

## Build and test

Run these commands from the `sownteeshell/` directory:

```sh
cargo build --release --locked --manifest-path backend/rust/core-daemon/Cargo.toml
cargo build --release --locked --manifest-path backend/rust/calendar-daemon/Cargo.toml

cargo test --locked --manifest-path backend/rust/core-daemon/Cargo.toml
cargo test --locked --manifest-path backend/rust/calendar-daemon/Cargo.toml
```

Check an installed session with:

```sh
systemctl --user status sownteeshell-core.service sownteeshell-calendar.service

./backend/rust/core-daemon/run-core-daemon request ping
./backend/rust/core-daemon/run-core-daemon check
./backend/rust/calendar-daemon/run-calendar-daemon request ping
./backend/rust/calendar-daemon/run-calendar-daemon check
```

Inspect daemon logs with:

```sh
journalctl --user -u sownteeshell-core.service -u sownteeshell-calendar.service
```
