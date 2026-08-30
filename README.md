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

## Highlights

### Desktop and navigation

- **Niri-native workspace model** with live windows, dynamic workspaces, overview-aware focus, drag reordering, cross-workspace movement without focus stealing, per-workspace tiled/floating state, and multi-monitor support.
- **Dynamic Dock** for pinned and running applications, with drag ordering, live window previews, focus-aware unread badges, right-click pinning, and overlap-aware auto-hide.
- **Launcher and All Apps** with fuzzy application search, a full-screen paged grid, horizontal touchpad navigation, keyboard control, and contextual app actions.
- **Search providers** for files (`f`), clipboard (`c`), calculator (`=`), and emoji (`e`). Clipboard history supports pinned text, URLs, colors, file lists, images, and video thumbnails with optional direct paste.
- **Configurable bar** with workspaces, active client, media and Cava, weather, battery, Wi-Fi, Bluetooth, microphone privacy, recording, notifications, clock, and StatusNotifier items.

### Panels, productivity, and system control

- **Left panel** with Vietnamese lunar calendar, Google Calendar events, local and Google Tasks, timed task indicators, OpenWeather forecasts with GeoClue location detection, synced lyrics, media controls, and countdown timers.
- **Right panel** with notification history, Wi-Fi and Bluetooth management, advanced IPv4/IPv6 profiles, Wi-Fi QR sharing, AirPods L/R/Case battery data, and a PipeWire per-application mixer with peak meters and device routing.
- **Display control** with drag-and-drop arrangement, orientation, mode, resolution, refresh rate, scale, startup focus, VRR (`Off`, `On`, `On Demand`), internal/external display presets, DDC/CI brightness, and Sunshine output selection.
- **System telemetry** with battery health and supported charge thresholds, power profiles, `auto-cpufreq`, Arch/AUR updates, live CPU/RAM/GPU charts, grouped process management, and RSS/PSS memory details.
- **Quick controls** for Airplane Mode, Caffeine, DND, night light, power profiles, Tailscale, and Cloudflare WARP, with edge-drag access to both panels.

### Settings

- A searchable, responsive, resizable **SownteeShell Settings** window that behaves like a regular Niri application.
- GUI editors for Niri keybindings, layout, input, animations, behavior, window and layer rules, and raw configuration files.
- Shell controls for typography, bar modules, launcher providers, notifications, wallpapers, capture, integrations, audio, OSDs, idle behavior, and performance.
- Per-surface blur, light/dark surface opacity, separate panel/component shadows, reduced motion, low-power mode, dependency diagnostics, and scoped cache cleanup.
- A shared profile image for Settings, Polkit, and Greetd, plus Howdy face-model management when supported.

### Wallpapers and Material You

- Static images, GIFs, and local videos, with video playback isolated in a separate Quickshell renderer process so its multimedia memory is reclaimed when playback stops.
- Wallpaper Engine support routes video projects through the native renderer and scene projects through `linux-wallpaperengine`, with battery-aware FPS and pause-on-lock/fullscreen policies.
- Integrated Wallhaven and Steam Workshop browsers with search, source-specific filters, favorites, installed-library management, cached previews, and desktop/Greetd/both destinations.
- Frame-aware video handoff, cached covers, rollback-safe transitions, and synchronized live theme previews while browsing.
- Matugen-generated Material You colors with animated shell transitions and optional theme propagation through configured system templates.
- Greetd keeps its own background and palette, generated independently from its selected image or Wallpaper Engine video.

### Capture and notifications

- A layered screenshot editor with pen, highlighter, lines, arrows, shapes, text, numbered markers, blur, pixelation, crop, eraser, zoom callouts, and a magnifier loupe.
- Transformable annotations and inserted image layers with move, crop, resize, rotate, opacity, visibility, z-order, edge snapping, automatic stitching, color picking, undo, and redo.
- English/Vietnamese OCR, Google Lens reverse image search, automatic clipboard export, and screenshot actions directly from the notification popup.
- GPU screen recording with region selection, configurable FPS/codec/quality, optional microphone capture, and CPU-encoding fallback.
- Grouped notification popups with application actions, priority-aware timeouts, configurable placement, direction-aware stacking, swipe dismissal, persistent history, scheduled DND, lock-screen delivery, exclusions, and retention controls.

### Session and runtime

- A standalone Quickshell Greetd interface on Cage with installed-session discovery, network status, animated battery state, profile sync, and wallpaper-derived colors.
- Multi-monitor PAM lock screen with password authentication, optional Howdy face recognition, retry after monitor wake, media, and notifications.
- Native Polkit dialogs, session and power menus, idle dim/lock/monitor-off policy, Caffeine inhibition, and position-aware volume, brightness, microphone, and media OSDs.
- On-demand QML surfaces, event-driven Niri/PipeWire/NetworkManager/UPower integration, a native image-cache provider, and a lazy Rust statistics backend with a Python fallback.

## Running the shell

After the runtime dependencies are available, launch the project from its root directory:

```bash
./run-sownteeshell
```

`run-sownteeshell` prepares the native image-cache plugin, configures the local QML import path and allocator behavior, then launches `shell.qml`.

## Architecture

```text
shell.qml              Entry point, IPC, screen variants, and lazy surfaces
Config.qml             Shared theme values and persisted runtime settings
StateManager.qml       Cross-surface state and open/close coordination
widget/                Bar, Dock, panels, desktop, capture, session, and Settings
components/            Reusable MD3 controls, effects, editors, and popups
service/               System, media, productivity, capture, and wallpaper services
backend/               On-demand Rust statistics and battery backend
plugin/                Native QML image-cache provider
scripts/               Niri, wallpaper, Google, display, capture, and auth helpers
```

The Niri Settings pages target the include-based configuration used by this setup; they are not intended as a generic editor for every possible Niri file layout. Runtime settings are stored under `$XDG_CACHE_HOME/quickshell` with `~/.cache/quickshell` as the fallback. API keys and account credentials are intentionally absent from source defaults.

## Dependencies

The main stack includes Niri, `quickshell-git`, Qt 6, PipeWire/WirePlumber, NetworkManager, UPower, Matugen, `wl-clipboard`, `cliphist`, FFmpeg, ImageMagick, and the capture utilities.

Optional or hardware-dependent features use Tesseract language data, GeoClue, Cava, `gpu-screen-recorder`, DDC/CI, Steam and `linux-wallpaperengine`, Howdy and V4L2, Tailscale, or Cloudflare WARP. Settings → Advanced → Dependencies reports which integrations are currently available.

Charge thresholds, external brightness, hardware video acceleration, face authentication, and device-specific battery telemetry depend on the machine and its drivers.

## Inspiration

Design and workflow inspiration comes from [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), [end-4's dots](https://github.com/end-4/dots-hyprland) and [Caelestia Shell](https://github.com/caelestia-dots/shell).

Built on the work of the [Niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org/), and [Matugen](https://github.com/InioX/matugen) communities.
