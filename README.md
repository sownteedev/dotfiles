<div align="center">

# SownteeShell

**A responsive Material You desktop shell built with Quickshell for Niri.**

[![Niri](https://img.shields.io/badge/Niri-scrollable_compositor-7C3AED?style=for-the-badge)](https://github.com/YaLTeR/niri)
[![Quickshell](https://img.shields.io/badge/Quickshell-Qt_6_%2F_QML-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.org/)

</div>

> [!IMPORTANT]
> SownteeShell is my personal desktop shell, built around my own Niri environment. This repository is a showcase of the project, not a supported drop-in shell or an installation-ready distribution.

## Showcase

<!--
Upload the finished demo video to GitHub, then replace the note below with the
GitHub-generated video attachment. This README intentionally uses one complete
video instead of a screenshot gallery.
-->

> [!NOTE]
> Video showcase coming soon.

## Overview

SownteeShell is a complete Quickshell desktop layer for Niri. It provides the bar, launcher, control panels, notifications, lock screen, wallpaper experience, capture tools, OSDs, power menu, settings, and the services that connect those surfaces to the system.

The visual language is based on Material Design 3. A palette generated from the current wallpaper flows through every shell surface, while shared spacing, typography, radii, and motion keep the experience consistent.

## Highlights

### Bar and workspaces

- Niri workspace state and active-client information remain independent from shell panel focus.
- Media controls and an optional Cava visualizer respond to the active MPRIS player.
- System tray items follow the same sizing and spacing system as native bar modules.
- Wi-Fi, Bluetooth, microphone privacy, battery, notifications, recording, and clock modules can be shown independently.
- Battery rendering includes animated liquid, wave, bubble, and charging states.

### Launcher

- Fast application discovery with optional fuzzy matching.
- Calculator expressions, clipboard history, emoji lookup, and file search.
- Keyboard-first navigation with animated result, width, and height transitions.
- Lazy loading keeps the launcher inactive until it is requested.

### Control center

- PipeWire output, input, stream, device, and volume controls.
- NetworkManager Wi-Fi scanning and connection management.
- Bluetooth device discovery, pairing, connection, and battery information.
- Airplane Mode, Caffeine, Do Not Disturb, Tailscale, and Cloudflare WARP quick toggles.
- Internal and DDC/CI external-display brightness controls.
- Display output profiles, hotplug handling, laptop-only, external-only, mirror, and extend modes.
- Night Light with adjustable color temperature and synchronized light/dark appearance.
- Battery health and charge-limit controls where supported.
- System statistics and a searchable process manager with process actions.
- Repository and AUR update checks with an integrated upgrade workflow.

### Settings and system tools

- Searchable Settings Hub for both Niri and SownteeShell configuration.
- Visual editors for Niri keybinds, layout, input, animations, behavior, rules, and KDL configuration files.
- Controls for bar modules, launcher providers, notifications, wallpapers, capture, integrations, idle behavior, and rendering performance.
- Dependency and service diagnostics with cache usage reporting and selective cleanup.
- Howdy face model enrollment, refresh, and removal from the security settings.

### Productivity and media

- Calendar, local todos, timers, and countdowns.
- Optional Google Calendar and Google Tasks integration.
- Weather data and animated weather presentation.
- MPRIS media controls, artwork, playback state, and synchronized lyrics.
- Caffeine and configurable idle behavior for focused work or long-running tasks.

### Wallpapers and color system

- Static local images with animated wallpaper transitions.
- Local video wallpapers through `mpvpaper`.
- Wallpaper Engine playback through `linux-wallpaperengine`.
- Steam Workshop search, download progress, cancellation, installed-item management, and subscription links.
- Wallhaven browsing, search, categories, purity, resolution, ratio, color, sorting, collections, and local management.
- Cached previews and downloads keep remote wallpaper browsing separate from personal wallpaper files.
- Matugen palette generation updates shared Material Design 3 tokens across the shell.
- Optional animated palette blending prevents abrupt color changes between wallpapers.

### Capture and notifications

- Screenshot selection, annotation, copy, save, open, and post-capture actions.
- OCR with language support for captured regions.
- Screen recording with configurable codec, quality, FPS, microphone, and output path.
- Notification popup queue, history, application filtering, Do Not Disturb scheduling, and fullscreen policy.
- Compact lock-screen notifications persist independently from notification history.
- Swipe-to-dismiss interactions and coordinated enter, exit, collapse, and reposition animations.

### Lock screen and security prompts

- Multi-screen lock surfaces coordinated through shared shell state.
- Password authentication with optional Howdy face authentication.
- Media, clock, session, and notification information without weakening the authentication boundary.
- Quickshell-native Polkit prompts for privileged actions initiated by the shell.

### Gestures, overlays, and power

- Edge-swipe gestures open the left and right panels with progress-following motion.
- Volume, microphone, and brightness OSDs share the shell's visual language.
- Power menu actions for shutdown, restart, lock, hibernate, suspend, and logout.

> and more features...

## Inspiration

SownteeShell takes inspiration from these open Linux desktop projects:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [end-4's Hyprland dots](https://github.com/end-4/dots-hyprland)
- [Caelestia Shell](https://github.com/caelestia-dots/shell)

Its foundation comes from the wider [Niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org/), and [Matugen](https://github.com/InioX/matugen) communities.

## Disclaimer

This is a personal and continuously evolving shell. It is shared as a showcase, with no promise that the complete environment will work on different hardware or match another user's workflow.
