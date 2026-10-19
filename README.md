<div align="center">

# SownteeShell

**A wallpaper-driven Material You desktop shell for Niri, built with Quickshell and Qt 6.**

[![Arch Linux](https://img.shields.io/badge/ARCH%20LINUX-PERSONAL%20SETUP-6d92bf?style=for-the-badge&labelColor=111418&logo=archlinux&logoColor=D9E0EE)](https://archlinux.org/)
[![Niri](https://img.shields.io/badge/NIRI-SCROLLABLE%20COMPOSITOR-da696f?style=for-the-badge&labelColor=111418)](https://github.com/YaLTeR/niri)
[![Quickshell](https://img.shields.io/badge/QUICKSHELL-QT%206%20%2F%20QML-74be88?style=for-the-badge&labelColor=111418&logo=qt&logoColor=D9E0EE)](https://quickshell.org/)

</div>

> [!IMPORTANT]
> SownteeShell is my personal Arch Linux and Niri setup. It is tuned around my workflow, hardware, and services, so treat it as a showcase and reference implementation rather than a supported drop-in desktop.

<div align="center">
  <video
    src="https://github.com/user-attachments/assets/b20c4242-4d8a-43b5-8cf5-5725194ba8b2"
    controls
    playsinline
    preload="metadata"
    width="900">
  </video>
</div>

## Highlights

### Desktop and navigation

- **Niri-native workspace model** with live windows, dynamic workspaces, overview-aware focus, drag reordering, cross-workspace movement without focus stealing, per-workspace tiled/floating state with a configurable default for new workspaces, and multi-monitor support.
- **Dynamic Dock** for pinned and running applications, with drag ordering, live window previews, focus-aware unread badges, right-click pinning, and overlap-aware auto-hide.
- **Launcher and All Apps** with fuzzy application search, a full-screen paged grid, horizontal touchpad navigation, keyboard control, contextual app actions, package-aware Pacman/Flatpak uninstall, and persistent drag-and-drop folders with rename and drag-out ungrouping.
- **Search providers** for files (`f`), clipboard (`c`), calculator (`=`), a unified emoji/Unicode catalog (`e`), and lazy KLIPY GIF (`g`) or sticker (`s`) grids when an API key is configured. Clipboard history supports pinned text, URLs, colors, file lists, images, and video thumbnails with optional direct paste.
- **Configurable bar** with workspaces, active client, media and Cava, weather, battery, Wi-Fi, Bluetooth, microphone privacy, recording, notifications, clock, and StatusNotifier items.

### Panels, productivity, and system control

- **Left panel** with Weather, Music, Stats, and Timer: OpenWeather/GeoClue forecasts, MPRIS playback and volume controls, stable artwork, synced lyrics with seeking, system charts, process management, and countdown timers.
- A standalone, responsive **SownteeShell Calendar** with:
    - Week/month views, Vietnamese lunar dates, a current-time indicator with auto-scroll, timeline zoom, and filtered event/task search with jump-to-date results.
    - Multi-day drag-to-create with 15-minute snapping and time validation; drag-to-move/resize for editable, non-recurring timed events. Other entry types use their editors.
    - Event details, all-day mode, calendar selection, location, description, daily/weekly/monthly/yearly recurrence with intervals and end rules, one synced reminder, availability, privacy, and iCalendar preview/import.
    - Multi-account Google Tasks with list selection, colors, inline editing/completion, dated tasks, and independently visible device-local tasks.
    - Account/calendar visibility, background sync, last-sync status, and reconnect controls for **Google, Microsoft, and iCloud/CalDAV**, backed by Rust, SQLite, and Secret Service.
- **Right panel** with Notifications, Wi-Fi/Ethernet, Bluetooth, Display, Power, and Volume: hardware-aware network controls, IPv4/IPv6 profiles, Wi-Fi QR sharing, AirPods battery levels, and per-app PipeWire mixing with peak meters and device routing.
- **Desktop and laptop power controls** with detected power modes, startup defaults, idle/sleep settings, and supported battery features: health, charge limits, low-battery automation, and separate battery/AC policies.
- **Display control** with single-screen, Duplicate, and Extend modes, independent main-display and Niri startup-focus choices, and drag arrangement with a 15-second revert safeguard. Includes orientation, resolution, refresh rate, scale, VRR, multi-output `wl-mirror` mirroring with source/target and Fit/Fill choices, DDC/CI brightness, and Sunshine output selection.
- **System telemetry** with battery health and supported charge thresholds, power profiles, `auto-cpufreq`, Arch/AUR/Flatpak updates, live CPU/RAM/GPU charts, grouped process management, and RSS/PSS memory details.
- **Quick controls** for Airplane Mode, Caffeine, DND, night light, power profiles, Tailscale, and Cloudflare WARP, with edge-drag access to both panels.

### Settings

- Searchable, responsive, resizable **SownteeShell Settings** with an MD3 Home dashboard, category shortcuts, palette preview, and animated tab transitions.
- **GTK & Qt appearance** and default applications: themes, shared icons, cursors, fonts, Qt styles/colors/dialogs, and preferred browser, file manager, terminal, editor, and image/video viewers. Settings synchronize across GTK, Qt, GSettings, and XWayland.
- GUI editors for Niri keybindings, layout, input, animations, behavior, window and layer rules, and raw configuration files.
- Shell controls for typography, bar modules, launcher providers, notifications, wallpapers, capture, integrations, audio, OSDs, idle behavior, and performance.
- **Startup & Services** with searchable Startup Apps, User Services, and System Services, live status filters, start/stop/restart controls, boot or login toggles, and Polkit-backed system actions. All three virtualized lists scroll independently on one fixed page, with search always visible.
- Per-surface blur, light/dark surface opacity, separate panel/component shadows, reduced motion, low-power mode, dependency diagnostics, and scoped cache cleanup.
- A shared profile image for Settings, Polkit, and Greetd, plus Howdy face-model management when supported.
- **SownteeShell Connect** for Wallhaven and Steam Community in Settings > Integrations, with themed sign-in windows and private, persistent website sessions. Expired sessions still require sign-in.

### Wallpapers and Material You

- Static images, GIFs, and local videos, with isolated video rendering and memory reclaimed when playback stops.
- Wallpaper Engine support routes video projects through the native renderer and scene projects through `linux-wallpaperengine`, with battery-aware FPS and pause-on-lock/fullscreen policies.
- Scene properties from `project.json`: switches, sliders, lists, text, and RGB controls, with per-wallpaper overrides and renderer-only restarts.
- Wallhaven and Steam Workshop browsers with search, filters, cached previews, source links, installed-library management, and desktop/Greetd/both destinations.
- **Wallhaven Collection** save/remove stars and favorite counts; **Workshop Browse / Subscribed / Installed** tabs with Subscribe/Unsubscribe actions. Remote subscriptions remain separate from local downloads.
- Permanent drag-to-delete for static and animated wallpapers, with active-wallpaper protection and a replacement-before-delete flow.
- Frame-aware video handoff, cached covers, rollback-safe transitions, and synchronized live theme previews while browsing.
- Matugen-generated Material You colors with animated shell transitions, soft secondary/tertiary accents for monochrome wallpapers, and optional theme propagation through configured system templates.
- Greetd keeps its own background and palette, generated independently from its selected image or Wallpaper Engine video.

### Capture and notifications

- A layered screenshot editor with pen, highlighter, lines, arrows, shapes, text, numbered markers, blur, pixelation, crop, eraser, zoom callouts, and a magnifier loupe.
- Transformable annotations and inserted image layers with move, crop, resize, rotate, opacity, visibility, z-order, edge snapping, automatic stitching, color picking, undo, and redo.
- English/Vietnamese OCR, Google Lens reverse image search, automatic clipboard export, and screenshot actions directly from the notification popup.
- Local QR detection via `zbar`, with multi-code previews and explicit copy/open actions; scanning never opens links or changes the clipboard automatically.
- GPU screen recording with region selection, configurable FPS/codec/quality, optional microphone capture, and CPU-encoding fallback.
- Grouped notification popups with application actions, priority-aware timeouts, configurable placement, direction-aware stacking, swipe dismissal, persistent history, scheduled DND, lock-screen delivery, exclusions, and retention controls.

### Session and runtime

- **Sowntee Horizon greeter for Greetd**, a standalone Quickshell interface on Cage with installed-session discovery, network and battery status, profile sync, power actions, and wallpaper-derived colors.
- A responsive login card with an avatar that morphs on password-length edits and a centered, enlarged clock after ten seconds of eligible inactivity, without interrupting authentication.
- PAM error and lockout feedback, with a live countdown when timing is available. During a known lock, submits check status without sending another password or restarting the timer.
- Multi-monitor PAM lock screen with password authentication, optional Howdy face recognition, camera preview and device-aware V4L2 controls, retry after monitor wake, media, and notifications.
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

The main stack includes Niri, `quickshell` (stable package), Qt 6, Rust/Cargo, PipeWire/WirePlumber, NetworkManager, UPower, Matugen, Material Symbols Rounded, `wl-clipboard`, `cliphist`, FFmpeg, ImageMagick, and the capture utilities.

Optional or hardware-dependent features use Tesseract language data, GeoClue, Cava, `gpu-screen-recorder`, DDC/CI, Steam and `linux-wallpaperengine`, Howdy and V4L2, Tailscale, or Cloudflare WARP. Wallpaper website accounts additionally require `pyside6` and `qt6-webengine`, with compatible Qt versions. The system greeter uses Greetd and Cage. Settings → Advanced → Dependencies reports which integrations are currently available.

Charge thresholds, external brightness, hardware video acceleration, face authentication, and device-specific battery telemetry depend on the machine and its drivers.

## Inspiration

Design and workflow inspiration comes from [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), [end-4's dots](https://github.com/end-4/dots-hyprland) and [Caelestia Shell](https://github.com/caelestia-dots/shell).

Built on the work of the [Niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org/), and [Matugen](https://github.com/InioX/matugen) communities.
