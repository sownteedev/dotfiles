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
│   ├── camera/             # V4L2 controls and device profiles
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
  Wi-Fi QR generation, screenshot QR decoding, and display integration for Niri, DDC/CI, and Sunshine;
- transactional Niri and SownteeShell settings, synchronized GTK 3/4 and Qt 5/6
  appearance (`settings.gtk.apply`, `settings.general.apply`: application themes, icons,
  cursor theme & size synchronized with Niri, interface typography, Kvantum/Fusion widget styles,
  color schemes, standard dialogs, and XSettings broadcast), default applications resolution,
  and greetd profile, session, background, and palette synchronization;
- Weather, Emoji/Unicode, KLIPY, Wallhaven, Steam Workshop, Wallpaper Engine
  project metadata and Scene property extraction, preview generation, and
  bounded media caches.

Shell-owned preferences include the default tiled/floating layout for new
workspaces and lunar-date visibility; these stay in persisted shell settings,
not separate Niri configuration files.

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

For installed Wallpaper Engine Scene projects, Core extracts supported entries
from `general.properties` in `project.json`. The shell builds the settings UI
from that metadata, stores only per-project overrides under
`$XDG_CACHE_HOME/sownteeshell/wallpaper-engine-properties.json`, and supplies
them as `--set-property` arguments when starting or restarting
`linux-wallpaperengine`; resetting a Scene removes its overrides without
modifying the original project.

Wallpaper library removal deletes permanently, with path validation and active
wallpaper protection. Local images/videos use `wallpaper.local.remove`; Wallhaven
and Workshop use their existing removal operations. QML owns the drag animation.

Run `sownteeshell ipc methods core` for its IPC methods and parameters.

`greeter-auth-status <user>` is a standalone, read-only lockout query. It resolves
the local greetd PAM stack and faillock policy, then reads Linux-PAM's native
64-byte tally records to report the current lock and its absolute expiry. It
does not authenticate, reset failures, start a daemon, or require new privileges.
Unreadable tallies, non-local users, conflicting policies, or unsupported data
return `known: false`; the greeter then keeps the PAM-provided notice instead of
guessing. In particular, the system greeter user may lack permission to read
another user's tally. Test Greeter runs as the desktop user and can read their
own tally. Repeated submits during a known lock only refresh this read-only
status; they do not send another password or restart the countdown.

`capture.qr.scan` accepts an absolute image `path` and uses local `zbarimg`
(`zbar`) with cancellation, an 8-second timeout, bounded output, and a 64 MiB
input-file limit. It returns deduplicated `codes` with `text`, `url`, and `host`;
only explicit HTTP/HTTPS links without embedded credentials receive an open
action. Images and QR content are not uploaded or persisted by this operation.
`clipboard.copyText` copies UTF-8 text through `wl-copy` only on user request.

## Calendar daemon

`rust/calendar-daemon` owns calendar accounts, events, and Google Tasks. It supports:

- Google Calendar through OAuth;
- Microsoft Calendar through Microsoft Graph OAuth;
- iCloud Calendar through CalDAV and an app-specific password;
- Google Tasks from all connected Google accounts and task lists, with cached
  snapshots, account-scoped mutations, and live updates in SownteeShell Calendar;
- account enable/disable and account-level visibility, calendar visibility, provider
  metadata, writable/read-only detection, and per-account sync status, last-sync
  timestamps, and errors;
- Google credential-expiry detection and account-specific reauthentication,
  with reconnect restricted to the original Google account;
- event create/update/delete with title, local start/end date-time, all-day spans,
  location, description, recurrence, availability, visibility, and reminder fields;
- daily, weekly, monthly, and yearly RRULE handling, including intervals, weekly
  `BYDAY`, monthly `BYMONTHDAY`, and `COUNT`/`UNTIL` termination (monthly rules
  retain the event's start day with `BYMONTHDAY`);
- iCalendar (`.ics` / `.ical`) parsing and batch import through
  `events.parseIcs` and `events.importIcs`, with event, recurrence, and supported
  `VALARM` reminder data round-tripped into the selected writable calendar;
- background synchronization, manual account/all-account refresh, live change
  notifications, cached event-range queries, and resilient refresh behavior;
- local SQLite persistence and one cloud-synchronized reminder per event. The
  reminder is written to the selected provider (Google Calendar popup,
  Microsoft Graph reminder, or CalDAV/iCloud `VALARM`); the daemon no longer
  runs a separate local reminder scheduler or creates multiple reminders.

Google Tasks uses the Calendar account's OAuth credentials. Existing Google
connections need to grant the additional Tasks scope by reconnecting in Calendar;
Google Tasks API must also be enabled in the OAuth project's Google Cloud console.
The previous Core Tasks backend and separate Tasks sign-in are no longer used.
Local tasks stay on this device and are never uploaded automatically.

Calendar search filters loaded events and dated tasks in QML; lunar-date display
is also a UI feature, not a separate backend service.

`tasks.list` returns per-account cached tasks and lists, including tasks without a
due date. Calendar renders dated tasks in the all-day lane; tasks without a due
date remain available through `tasks.list`. `tasks.setVisible` only changes Calendar visibility.
Task refresh failures preserve the previous complete snapshot and report a
per-account error without stopping event synchronization. See `sownteeshell ipc
methods calendar` for the task methods and their required account/list identifiers.

Google Tasks mutations are account- and list-scoped. The Calendar task editor can
create, update, complete, and delete Google Tasks after selecting the Google account
and task list; it can also create and edit device-only Local Tasks. Local Tasks are
not sent to Google, Microsoft, iCloud, or the calendar daemon. Dated tasks are
exposed to the Calendar UI as all-day entries, while tasks without a due date remain
available only in the task list.

The Calendar UI consumes these calendar IPC methods:

```text
accounts.list
accounts.google.add
accounts.google.reconnect
accounts.microsoft.add
accounts.icloud.add
accounts.remove
accounts.setEnabled
calendars.list
calendars.setVisible
events.list
events.create
events.update
events.delete
events.parseIcs
events.importIcs
tasks.list
tasks.setVisible
tasks.google.refresh
tasks.google.create
tasks.google.update
tasks.google.delete
sync.now
```

Moving or resizing an event in the Week view is implemented as a normal
`events.update` request. The UI restricts that gesture to editable, timed,
non-recurring events; recurring series, all-day entries, tasks, and read-only
calendars must be edited through their respective editor/provider rules.

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
- `python/camera/v4l2_controls.py` reads supported V4L2 controls, applies individual
  values, restores driver defaults, and saves per-device camera profiles for the
  Settings preview.
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

## Wallpaper website accounts

Settings > Integrations connects Wallhaven and Steam Community through
`python/wallpaper/web_account.py`, a dedicated PySide6/Qt WebEngine window.
The optional wallpaper package group in `install/.installconfigtheme` includes
`pyside6` and `qt6-webengine`; their Qt versions must match the installed Qt stack.
Opening the normal browser is not sufficient: complete login in this window,
press **Check sign-in** if needed, and then **Use this account**. The user must
complete Steam Guard and any CAPTCHA themselves. No browser profile is imported.

The connection window uses the shell's Matugen `colors.json` (`md3` tokens),
including live updates when the file is rewritten or replaced. It keeps the last
valid palette during incomplete writes and uses a built-in fallback if no theme
is available. The header, website address, progress indicator, and actions are
themed; the official website is not restyled or replaced. The browser receives
the remaining vertical space instead of stretching the instructions. The window
uses the shell's configured `fontName` at launch and provides Reload and Cancel.

The helper identifies its window as **SownteeShell Connect**, with app ID
`sownteeshell-connect` and a bundled link icon with the circular S signature.
The workspace bar, dock, and dock preview use the same Matugen-colored
`SownteeAppIcon` tile, outline, and S badge as Settings. Identity resolution
recognizes this ID without installing a desktop launcher or changing Python's
identity for unrelated applications. Reopen the connection window after updating;
the shell also needs to load the updated workspace service for bar/dock branding.
The dotfiles Niri rule matches this app ID and opens a 1040 x 800 floating window
with the same 26px corner radius and background-effect policy as Settings.

The shell keeps a separate profile for each provider under
`$XDG_DATA_HOME/sownteeshell/web-accounts/` (by default
`~/.local/share/sownteeshell/web-accounts/`). Directories use mode 700, account
metadata uses mode 600, and the helper runs with umask 077. Website cookies and
storage grant access to the account: treat this directory as sensitive and do
not sync it to dotfiles or share it. This is filesystem access protection, not
an application-level encrypted vault. Disconnect removes only the shell's local
profile, not remote collections/subscriptions or the browser/SteamCMD login.

On shell startup or reload, each account connection restores its saved identity
from local metadata without opening WebEngine or requiring network access.
This restores the linked-account UI, not proof that the website session is still
valid: status checks and every remote operation continue to verify the website
identity. Authentication failures mark the connection unavailable but retain its
saved identity and profile so a later check can recover. Only an explicit
Disconnect removes the stored account; genuinely expired sessions still require
sign-in again.

Shell-launched account helpers use `--watch-stdin` to tie their lifetime to the
owning process's input pipe. Closing that pipe during shell reload or exit
disposes the WebEngine page and profile and releases the provider lock without
deleting account storage. SIGTERM also follows this cleanup path, and a closed
output pipe cannot skip cleanup. Direct CLI
requests without this flag still support piped JSON followed by EOF. Do not
delete a provider lock while its helper is running or automatically retry a
save/subscription mutation interrupted by a reload; check the website first.

Wallhaven's card action posts an unsaved wallpaper directly to the first
available collection of the connected website account; it no longer opens a
collection chooser for every save. Its API username/key remain separate;
API collection views refresh after a save or removal only when
the configured username matches the website account. The saved-state star is
an action: click it to remove the wallpaper from Collection using Wallhaven's
own wallpaper-page `/favorites/delete/<id>` control, not the collection-list
`quickDelete` control. An unrecognized control is an integration error, not proof
that the wallpaper is absent from Collections. Unsaved items use the first
available collection automatically.
Loaded collection pages and confirmed saves also mark matching Browse/Installed
cards for the same account during the shell session. This is not a complete
background sync of all collections; unknown membership keeps the save action.
Membership learned in-session is cleared when the account configuration changes.

Workshop's Subscribe action uses the connected Steam Community session, checks
the item belongs to Wallpaper Engine (431960), submits a subscription, then
reloads its page to verify it. The same button offers Unsubscribe for subscribed
items and Subscribe otherwise; each request explicitly sets the desired state.
SteamCMD downloads and linux-wallpaperengine playback
remain independent. A local Steam manifest is not proof of a new remote write.
Confirmed remote states, including unsubscribed, take precedence over a stale
local manifest during the session and reset when the connected account changes.
Downloaded and In Use remain separate; these actions do not delete local files.

The Workshop tabs are Browse, Subscribed, and Installed, in that order.
Subscribed reads the connected account's Wallpaper Engine subscriptions from
Steam Community, with independent pagination and Reload/Connect controls.
The last subscription page is cached for two minutes across tab switches and
panel reopenings; Reload always requests fresh data. Confirmed Unsub actions
remove only that item locally without reloading the full subscription list.
Sub/Unsub clicks are serialized per connected account, with a single spinner
on each pending card; changing accounts discards queued actions.
Background Steam requests skip images, fonts, and media, reuse the private
HTTP cache, and read the subscription page directly instead of loading a
profile page first. Interactive sign-in remains unchanged.
It does not use the public "Most subscribed" ranking or require a Web API key.
Browse results and their sort/filter state remain independent. Unsubscribe
removes the item from the subscription view without deleting local files.
Local/Browse metadata enriches matching cards. The subscription list does not
provide content ratings; missing ratings do not mark a wallpaper as NSFW.
Cards are labeled and blurred as NSFW only when matching metadata flags them.

These are unofficial website integrations, not new permissions on API keys.
Expired sessions, changed accounts, unexpected website markup, missing
dependencies, and rejected writes are errors; the UI must not claim success.
The helper serializes requests per provider and does not automatically retry
mutations after timeouts. Check the website before retrying an uncertain write.

Safe syntax check (no account login or mutation):

```sh
node --check backend/python/wallpaper/web_account.js
```

Manual validation after installing matching Qt dependencies and reloading the
shell: connect each account, confirm its displayed identity, save one wallpaper
to a selected Wallhaven collection, remove it again, subscribe/unsubscribe one
Workshop item, and verify both on the corresponding websites. Also check
disconnect/reconnect and expired
sessions. Do not claim live completion based only on offline tests.

## Default workspace layout

`defaultWorkspaceLayout` is a Quickshell setting (`tiled` or `floating`, default
`tiled`) declared in `Config.qml` and `core-daemon/src/settings/defaults.json`.
Settings > Niri > Layout includes it in Apply layout; after Niri accepts the
layout, the backend saves it through the shared Quickshell settings sanitizer
and atomic cache writer. It can also be saved with `settings.quickshell.apply`.
If the cache write fails after Niri applies, the UI reports that partial failure.

The persisted value lives in `$XDG_CACHE_HOME/sownteeshell/settings.json`
(normally `~/.cache/sownteeshell/settings.json`), not in Niri's config tree.
`dotf/.config/niri/scripts/niri-floating-daemon.py` and the toggle helper read
that same cache. New active workspaces (or workspaces receiving their first
window) use the current default. The bar button and Mod+Shift+V override only
their workspace and never change the default; returning preserves the override.

Per-workspace true/false choices remain session state in
`$XDG_RUNTIME_DIR/niri-floating-workspaces.json`. An updated daemon preserves
them when restarted in the same Niri session and resets them for a new session.
After upgrading the Python script, restart that daemon or start a new Niri
session once; later setting changes are read without another restart.
