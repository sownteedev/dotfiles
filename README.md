<div align="center">

# SownteeShell

**A Material You desktop shell for Niri, built with Quickshell and Qt 6.**

[![Niri](https://img.shields.io/badge/Niri-scrollable_compositor-7C3AED?style=for-the-badge)](https://github.com/YaLTeR/niri)
[![Quickshell](https://img.shields.io/badge/Quickshell-Qt_6_%2F_QML-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.org/)

</div>

> [!IMPORTANT]
> SownteeShell is a personal shell built around my Arch Linux and Niri environment. It is published as a project showcase and reference, not as a supported drop-in desktop or standalone installer.

## Showcase

<!--
Upload the finished demo video to GitHub, then replace the note below with the
GitHub-generated video attachment.
-->

> [!NOTE]
> Video showcase coming soon.

## Overview

SownteeShell provides the bar, launcher, control panels, notifications, lock screen, wallpaper system, capture tools, OSDs, power menu, settings, and system services for a complete Niri desktop session.

Its interface follows Material Design 3, with wallpaper-derived colors, real background blur, shared typography and spacing, responsive layouts, and motion that can be reduced for lower-power devices.

## Features

### Bar and workspaces

- Live Niri workspace and active-window tracking, including dynamic workspace creation.
- Drag-and-drop window reordering and movement between workspaces without focus stealing.
- Per-workspace tiled/floating switching from the bar.
- Persistent multi-monitor app Dock with drag reordering, overlap-aware auto-hide, and focus-aware unread notification badges.
- MPRIS media widget with playback controls, seeking, `LIVE` status, animated empty state, and Cava visualization.
- Configurable weather, battery, Wi-Fi, Bluetooth, microphone privacy, recording, DND, clock, and system tray modules.

### Launcher and All Apps

- Unified fuzzy app search with dedicated modes for files (`f`), clipboard (`c`), calculations (`=`), and emojis (`e`).
- Full-screen All Apps grid with responsive sizing, animated filtering, and keyboard navigation using arrows, `Home`, `End`, `Page Up/Down`, and `Enter`.
- Clipboard history for text, files, images, and videos, with thumbnails, pinned entries, and optional direct paste.
- Emoji search and direct paste into the previously focused application.
- Right-click app actions for launching and pinning or removing entries from the Dock.
- Lazy-loaded result providers and adaptive launcher geometry when no results are available.

### Control panels and productivity

- Calendar with Vietnamese lunar dates, event indicators, date/time pickers, and Google Calendar integration.
- Local tasks and Google Tasks integration, including create, update, complete, delete, and local-to-Google sync.
- Current, hourly, and daily weather from OpenWeather, with GeoClue-assisted location detection.
- Synced music lyrics and a configurable countdown timer with desktop notifications.
- PipeWire mixer with per-application volume, peak meters, mute controls, and input/output device routing.
- Wi-Fi and Bluetooth management, advanced IPv4/IPv6 profile editing, and AirPods L/R/Case battery monitoring.
- Quick toggles for Airplane Mode, Caffeine, DND, Tailscale, Cloudflare WARP, night light, and power profiles.
- Display modes for internal, external, and extended layouts; internal backlight and external DDC/CI brightness; Sunshine capture-output profiles.
- Battery health, charge-preservation controls, `auto-cpufreq`, live CPU/RAM/GPU charts, process management, and Arch/AUR update checks.

### Settings Hub

- Searchable GUI settings for both Niri and the shell.
- Niri editors for keybindings, layout, input devices, animations, behavior, window/layer rules, and raw configuration files.
- Shell controls for appearance, font selection, bar modules, launcher providers, notifications, wallpapers, capture, integrations, performance, audio, and OSD behavior.
- Independent background-blur toggles for the bar, Dock, launcher, Settings, and both control panels, with separate light/dark surface opacity.
- Shared Material You shadow controls for large panels and compact components, including blur, opacity, spread, and offsets.
- Face-authentication management, idle and power policy, dependency diagnostics, and cache cleanup.
- Contextual Apply actions, with Reset shown only when a page has unsaved changes.

### Wallpapers and theming

- Static wallpapers and video/GIF loops use native Qt playback; Steam Workshop video projects use the same renderer, while scene projects use `linux-wallpaperengine`.
- Integrated Wallhaven and Steam Workshop browsers with responsive preview grids, installed-library management, and source-specific filters for category, purity, resolution, aspect ratio, color, rating, features, genre, and sorting.
- Per-item actions can download, preview, subscribe, and target the desktop, Greetd, or both; Greetd accepts Wallhaven images and Wallpaper Engine video projects.
- Greetd keeps an independent Material You palette generated from its selected image or a representative video frame, so desktop wallpaper changes do not recolor the login screen.
- Playback policy that can pause wallpapers while locked or fullscreen and reduce Wallpaper Engine FPS on battery power.
- Dual-player video handoff waits for a decoded frame before crossfading, while cached covers, transition rollback, and Matugen stay synchronized.
- Automatic Material You palette generation through Matugen, with animated shell color transitions and optional propagation through the surrounding dotfiles templates.
- Cached wallpaper backdrops for consistent blurred desktop surfaces.

### Capture and notifications

- Region screenshots with an in-shell editor for crop, freehand drawing, arrows, rectangles, text, blur, pixelation, undo, and color selection.
- OCR with English/Vietnamese language support and Google Lens reverse image search.
- GPU screen recording with configurable region, FPS, codec, quality, microphone capture, and CPU-encoding fallback.
- Grouped notification popups with configurable top, top-right, or bottom-right placement, direction-aware stacking, application actions, swipe-to-dismiss, expandable groups, and persistent history.
- Lock-screen notification stacks, scheduled DND, critical-notification handling, popup exclusions, history exclusions, and configurable retention limits.

### Security and session

- Standalone Quickshell Greetd interface on Cage, with installed-session discovery, network and battery status, and a clean handoff into the selected Wayland session.
- Multi-monitor PAM lock screen with password authentication, optional Howdy face recognition, and retry after monitor wake.
- Idle dimming followed by monitor power-off, with separate unlocked and locked timeouts plus Caffeine inhibition.
- Native Polkit authentication dialogs and configurable top/bottom volume, brightness, microphone, and media OSDs with matching transitions.
- Edge-drag gestures for opening the left and right control panels.
- Animated session menu for Lock, Suspend, Hibernate, Logout, Reboot, and Shutdown.

## Technical foundation

- Qt 6/QML user interface built on Quickshell singletons, loaders, and Wayland layer surfaces.
- Event-driven integration with Niri, PipeWire, NetworkManager, UPower, MPRIS, and StatusNotifierItem.
- On-demand polling and subprocess lifecycle control for weather, statistics, Bluetooth scanning, wallpaper discovery, and external integrations.
- Persistent settings and history use debounced or atomic writes to avoid unnecessary disk activity and partial files.

## Inspiration

SownteeShell takes inspiration from these open Linux desktop projects:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [end-4's Hyprland dots](https://github.com/end-4/dots-hyprland)
- [Caelestia Shell](https://github.com/caelestia-dots/shell)

Its foundation comes from the wider [Niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org/), and [Matugen](https://github.com/InioX/matugen) communities.

## Disclaimer

Features that integrate with external tools or online services require their corresponding packages, permissions, credentials, and system configuration. Hardware-specific controls such as DDC/CI brightness, charge preservation, GPU encoding, and face authentication depend on compatible devices.
