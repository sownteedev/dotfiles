<div align="center">

# SownteeShell

**A wallpaper-driven Material You desktop shell for Niri, built with Quickshell and Qt 6.**

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-personal_setup-1793D1?style=flat-square&logo=archlinux&logoColor=white)](https://archlinux.org/)
[![Niri](https://img.shields.io/badge/Niri-scrollable_compositor-7C3AED?style=flat-square)](https://github.com/YaLTeR/niri)
[![Quickshell](https://img.shields.io/badge/Quickshell-Qt_6_%2F_QML-41CD52?style=flat-square&logo=qt&logoColor=white)](https://quickshell.org/)

</div>

> [!IMPORTANT]
> SownteeShell is my personal Arch Linux and Niri setup. It is tuned around my workflow, hardware, and services, so treat it as a showcase and reference implementation rather than a supported drop-in desktop.

## Showcase

<!--
Upload the finished demo video to GitHub, then replace the note below with the
GitHub-generated video attachment.
-->

> [!NOTE]
> Video showcase coming soon.

SownteeShell is the desktop UI and runtime layer of my Niri session: bar, Dock, launcher, control panels, notifications, wallpapers, capture tools, Settings, lock screen, greeter, OSDs, and system integration.

Every surface shares one Material Design 3 language, wallpaper-derived colors, compositor-backed blur, typography, motion, and state. Large interfaces are loaded only when opened, while system services follow their actual consumers instead of polling permanently.

The visual layer uses shared MD3 typography, shape, spacing, state, motion, and elevation tokens. Material Symbols Rounded provides consistent shell action icons while application, provider, and brand icons retain their native artwork; freedesktop symbolic icons remain the runtime fallback.

## Highlights

### Desktop and navigation

- **Niri-native workspace model** with live windows, dynamic workspaces, overview-aware focus, drag reordering, cross-workspace movement without focus stealing, per-workspace tiled/floating state, and multi-monitor support.
- **Dynamic Dock** for pinned and running applications, with drag ordering, live window previews, focus-aware unread badges, right-click pinning, and overlap-aware auto-hide.
- **Launcher and All Apps** with fuzzy application search, a full-screen paged grid, horizontal touchpad navigation, keyboard control, contextual app actions, package-aware Pacman/Flatpak uninstall, and persistent drag-and-drop folders with rename and drag-out ungrouping.
- **Search providers** for files (`f`), clipboard (`c`), calculator (`=`), a unified emoji/Unicode catalog (`e`), and lazy KLIPY GIF (`g`) or sticker (`s`) grids when an API key is configured. Clipboard history supports pinned text, URLs, colors, file lists, images, and video thumbnails with optional direct paste.
- **Configurable bar** with workspaces, active client, media and Cava, weather, battery, Wi-Fi, Bluetooth, microphone privacy, recording, notifications, clock, and StatusNotifier items.

### Panels, productivity, and system control

- **Left panel** with Weather and Music tabs above Stats and Timer: OpenWeather forecasts with GeoClue location detection, MPRIS media controls with decoded artwork frame retention to eliminate loading blackouts, inline volume slider, expandable synced lyrics with playback position seeking, live CPU/RAM/GPU charts, grouped process management, RSS/PSS memory details, and countdown timers.
- A standalone, responsive **SownteeShell Calendar** with:
  - Week and month views, Vietnamese lunar dates, a current-time indicator, and automatic scrolling to the current hour when the week view opens.
  - Drag-to-create events across one or multiple days, with 15-minute snapping and local start/end validation.
  - Direct manipulation of existing timed events: drag an editable non-recurring event to another day or time, or drag its top/bottom edge to change the start/end time. All-day, task, read-only, and recurring entries remain editor-only to avoid changing the wrong occurrence or series.
  - Week timeline zoom controls with Zoom in/Zoom out buttons and `Ctrl` + mouse wheel; normal wheel scrolling continues to scroll the timeline.
  - Event editing for title, start/end dates and times, all-day mode, destination calendar, location, description, recurrence, one provider-synchronized reminder, availability (`Busy`/`Free`), and visibility (`Default`/`Public`/`Private`).
  - Daily, weekly, monthly, and yearly recurrence, weekly weekday selection, interval values, and recurrence termination by date or count. Monthly rules preserve the event's start day with `BYMONTHDAY`.
  - iCalendar (`.ics`/`.ical`) parsing, preview, and import into a selected writable calendar, including supported event details, recurrence, and reminder data.
  - Google Tasks from every connected Google account and task list, with account/list colors, account and list selection when creating a task, inline editing/completion, and dated tasks rendered in the all-day lane. Local Tasks remain device-only and can be shown or hidden independently.
  - Sidebar account and calendar visibility controls, per-provider status/error feedback, manual sync, and automatic background synchronization.
- Calendar sync for **Google, Microsoft, and iCloud/CalDAV**, backed by a dedicated Rust daemon with a local SQLite cache, Secret Service credentials, provider-aware event options, live refresh, and one provider-synchronized reminder per event.
- **Right panel** with Notifications, Wi-Fi, and Bluetooth tabs above Display, Battery, and Volume. Includes advanced IPv4/IPv6 profiles, Wi-Fi QR sharing, AirPods L/R/Case battery data, and a PipeWire per-application mixer with peak meters and device routing.
- **Display control** with drag-and-drop arrangement, orientation, mode, resolution, refresh rate, scale, startup focus, VRR (`Off`, `On`, `On Demand`), internal/external display presets, DDC/CI brightness, and Sunshine output selection.
- **System telemetry** with battery health and supported charge thresholds, power profiles, `auto-cpufreq`, Arch/AUR/Flatpak updates, live CPU/RAM/GPU charts, grouped process management, and RSS/PSS memory details.
- **Quick controls** for Airplane Mode, Caffeine, DND, night light, power profiles, Tailscale, and Cloudflare WARP, with edge-drag access to both panels.

### Settings

- A searchable, responsive, resizable **SownteeShell Settings** window featuring an MD3 **Home** dashboard with quick-jump category cards, color palette preview, and seamless tab transitions.
- **Desktop applications (GTK & Qt)** appearance and default application choices: browser, file manager, terminal, text editor, image and video viewer, synchronized across GSettings, GTK 3/4 `settings.ini`, `qt5ct`/`qt6ct`, and XWayland XSettings: GTK themes, one shared icon theme for applications and SownteeShell, cursor theme and size (px), interface typography, Qt widget styles, Qt color schemes, and Qt standard dialogs.
- GUI editors for Niri keybindings, layout, input, animations, behavior, window and layer rules, and raw configuration files.
- Shell controls for typography, bar modules, launcher providers, notifications, wallpapers, capture, integrations, audio, OSDs, idle behavior, and performance.
- Per-surface blur, light/dark surface opacity, separate panel/component shadows, reduced motion, low-power mode, dependency diagnostics, and scoped cache cleanup.
- A shared profile image for Settings, Polkit, and Greetd, plus Howdy face-model management when supported.

### Wallpapers and Material You

- Static images, GIFs, and local videos, with video playback isolated in a separate Quickshell renderer process so its multimedia memory is reclaimed when playback stops.
- Wallpaper Engine support routes video projects through the native renderer and scene projects through `linux-wallpaperengine`, with battery-aware FPS and pause-on-lock/fullscreen policies.
- Installed Scene projects expose a Material 3 properties panel generated from their `project.json`, with project-defined switches, sliders, option lists, text values, and RGB controls. Overrides are saved per wallpaper and applied by restarting only the active `linux-wallpaperengine` renderer.
- Integrated Wallhaven and Steam Workshop browsers with search, source-specific filters, favorites, installed-library management, cached previews, and desktop/Greetd/both destinations.
- Frame-aware video handoff, cached covers, rollback-safe transitions, and synchronized live theme previews while browsing.
- Matugen-generated Material You colors with animated shell transitions, soft secondary/tertiary accents for monochrome wallpapers, and optional theme propagation through configured system templates.
- **Sowntee Horizon greeter for Greetd** with a cinematic, asymmetric layout: left-aligned clock and date typography, Sowntee shell session header, Material 3 Login Card, high-contrast readability gradient veil over custom wallpapers, decorative S-orbit curves, top-right status cluster (network and battery pills), and bottom-right power actions.
- Greetd keeps its own background and palette, generated independently from its selected image or Wallpaper Engine video.

### Capture and notifications

- A layered screenshot editor with pen, highlighter, lines, arrows, shapes, text, numbered markers, blur, pixelation, crop, eraser, zoom callouts, and a magnifier loupe.
- Transformable annotations and inserted image layers with move, crop, resize, rotate, opacity, visibility, z-order, edge snapping, automatic stitching, color picking, undo, and redo.
- English/Vietnamese OCR, Google Lens reverse image search, automatic clipboard export, and screenshot actions directly from the notification popup.
- Local QR detection in screenshot notifications: preview detected content, copy text, or explicitly open HTTP/HTTPS links. Multiple codes are listed separately; scanning never opens links or changes the clipboard automatically. Requires `zbar`.
- GPU screen recording with region selection, configurable FPS/codec/quality, optional microphone capture, and CPU-encoding fallback.
- Grouped notification popups with application actions, priority-aware timeouts, configurable placement, direction-aware stacking, swipe dismissal, persistent history, scheduled DND, lock-screen delivery, exclusions, and retention controls.

### Session and runtime

- A standalone Quickshell Greetd interface on Cage with installed-session discovery, network status, animated battery state, profile sync, and wallpaper-derived colors.
- Multi-monitor PAM lock screen with password authentication, optional Howdy face recognition, retry after monitor wake, media, and notifications.
- Native Polkit dialogs, session and power menus, idle dim/lock/monitor-off policy, Caffeine inhibition, and position-aware volume, brightness, microphone, and media OSDs.
- On-demand QML surfaces, event-driven Niri/PipeWire/NetworkManager/UPower integration, a native image-cache provider, and persistent Rust Core and Calendar services with direct IPC, bounded jobs, and systemd-managed lifecycles.

## Architecture

```text
shell.qml              Entry point, IPC, screen variants, and lazy surfaces
Config.qml             Shared theme values and persisted runtime settings
StateManager.qml       Cross-surface state and open/close coordination
widget/                Bar, Dock, panels, desktop, capture, session, and Settings
components/            Reusable MD3 controls, effects, editors, and popups
service/               System, media, productivity, capture, and wallpaper services
backend/               Rust Core/Calendar services and on-demand Python/native helpers
plugin/                Native QML image-cache provider
scripts/               Shell integrations grouped by capture, connectivity, power, and theme
```

The Niri Settings pages target the include-based configuration used by this setup; they are not intended as a generic editor for every possible Niri file layout. Runtime settings and shell-owned caches are stored under `$XDG_CACHE_HOME/sownteeshell` with `~/.cache/sownteeshell` as the fallback; Quickshell's own QML, shader, pipeline, and crash caches remain under its native cache directory. API keys and account credentials are intentionally absent from source defaults.

## Dependencies

The main stack includes Niri, `quickshell-git`, Qt 6, Rust/Cargo, PipeWire/WirePlumber, NetworkManager, UPower, Matugen, Material Symbols Rounded, `wl-clipboard`, `cliphist`, FFmpeg, ImageMagick, and the capture utilities.

Optional or hardware-dependent features use Tesseract language data, GeoClue, Cava, `gpu-screen-recorder`, DDC/CI, Steam and `linux-wallpaperengine`, Howdy and V4L2, Tailscale, or Cloudflare WARP. Settings → Advanced → Dependencies reports which integrations are currently available.

Charge thresholds, external brightness, hardware video acceleration, face authentication, and device-specific battery telemetry depend on the machine and its drivers.

## Inspiration

Design and workflow inspiration comes from [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), [end-4's dots](https://github.com/end-4/dots-hyprland) and [Caelestia Shell](https://github.com/caelestia-dots/shell).

Built on the work of the [Niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org/), and [Matugen](https://github.com/InioX/matugen) communities.
