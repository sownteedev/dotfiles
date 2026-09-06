# SownteeShell backend

This directory contains the non-visual implementation used by SownteeShell.
QML owns presentation and short-lived UI state; backend code owns blocking,
privileged, stateful, or performance-sensitive work.

## Layout

```text
backend/
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
- clipboard restoration, diagnostics, updates, Wi-Fi QR generation, and
  display integration for Niri, DDC/CI, and Sunshine;
- transactional Niri and SownteeShell settings, GTK/XSettings theme updates,
  and greetd profile, session, background, and palette synchronization;
- Weather, Emoji/Unicode, KLIPY, Wallhaven, Steam Workshop, Wallpaper Engine,
  preview generation, and bounded media caches;
- Google Tasks authentication and Todo synchronization.

The default socket is:

```text
$XDG_RUNTIME_DIR/sownteeshell/core/core.sock
```

`CoreService.qml` maintains shared request and subscription sockets. Feature
services use `CoreRequest.qml` for cancellable work, so closing a provider or
starting a newer search can cancel the previous backend job without spawning a
new helper process for every request.

The daemon uses a four-thread Tokio runtime, moves blocking filesystem work off
the async workers, reuses one bounded HTTP client, limits IPC messages to 1 MiB
requests and 16 MiB responses, and applies feature-level limits to downloads,
command output, and caches. Long-running renderers, SteamCMD, FFmpeg,
ImageMagick, Matugen, and privileged system commands remain separate processes
by design.

See [`rust/core-daemon/README.md`](rust/core-daemon/README.md) for its IPC
methods and compatibility commands.

## Calendar daemon

`rust/calendar-daemon` is independent from Google Tasks and is dedicated to
calendar data. It supports:

- Google Calendar through OAuth;
- Microsoft Calendar through Microsoft Graph OAuth;
- iCloud Calendar through CalDAV and an app-specific password;
- account and calendar visibility, event create/update/delete, background
  synchronization, and live change subscriptions;
- local SQLite persistence and deduplicated desktop reminders 30 minutes
  before an event.

The default socket and database are:

```text
$XDG_RUNTIME_DIR/sownteeshell/calendar/calendar.sock
$XDG_DATA_HOME/sownteeshell/calendar/calendar.db
```

OAuth tokens, client secrets, and CalDAV passwords are stored through the
desktop Secret Service rather than in the repository or SQLite database. The
default sync interval is 15 minutes, with a 90-day past window and a 365-day
future window. These values can be overridden with:

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
