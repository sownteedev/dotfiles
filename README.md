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

### 🌟 Top Bar & Dynamic Workspaces

- **Niri Workspace Tracking:** Real-time workspace indicators and active-window title tracker that remain synchronized across dynamic workspace creation and window focusing.
- **Interactive Media Player:** Adaptive track title and artist ticker with `LIVE` broadcast badges, interactive scrubber dragging, and an audio-reactive **Cava visualizer**.
- **Intelligent Battery Widget:** Custom vector-rendered battery with animated liquid waves, bubble flows during charging, and critical level visual alerts.
- **Unified Status Center:** Discrete indicators for Wi-Fi signal strength, Bluetooth connection & battery levels, Microphone privacy guard, Screen recording status, Do Not Disturb, and System Clock.
- **Modern System Tray:** Pixel-aligned StatusNotifierItem host conforming strictly to the shell's Material You padding, spacing, and typography.

### 🚀 Spotlight Launcher

- **Multi-Provider Architecture:** Search apps, run inline mathematical calculations (`=`), query clipboard history (`c`), search local files (`f`), and look up Unicode emojis (`e`).
- **Fuzzy Matching Engine:** Instant, typo-tolerant search across all installed `.desktop` applications and binaries.
- **Adaptive Geometry:** Smooth, responsive height and width animations as results filter down, with complete keyboard navigation support (`Tab`, `Arrows`, `Return`).
- **Zero-Idle Footprint:** Component instances are lazily loaded on demand and immediately unloaded when dismissed.

### 🎛️ Comprehensive Control Center

- **Audio & Device Routing:** Per-stream PipeWire volume sliders, peak level monitors, audio input/output device switching, and individual application muting.
- **Network & Privacy Toggles:** One-click toggles for Wi-Fi Networks, Bluetooth, Airplane Mode, Caffeine, Do Not Disturb, Tailscale VPN, and Cloudflare WARP.
- **Apple AirPods Integration:** Custom native BLE reader showing granular battery levels for Left earbud, Right earbud, and Charging Case.
- **Display & Brightness Management:** Dual controls for internal laptop backlight and external monitor **DDC/CI hardware brightness**, display output profile selection (Mirror, Extend, Internal-Only, External-Only), and smart hotplug detection.
- **Game Streaming Profile Switcher:** Integrated Sunshine display output profile management with automatic capture source assignment and service restart.
- **Night Light & Color Tuning:** Seamless gamma temperature transitions synchronized with system-wide Dark/Light theme modes.
- **Battery Health & Charge Thresholds:** Real-time battery degradation health checks and ASUS/Lenovo hardware charge-limit toggles.
- **System Diagnostics & Process Manager:** Live CPU/RAM/GPU usage charts with integrated process discovery, searchable process list with animated loading indicator, and instant process termination (`SIGTERM`/`SIGKILL`).
- **Package & Update Manager:** Automated Arch Linux official repositories and AUR update checker with an integrated one-click terminal upgrade workflow.

### ⚙️ Searchable Settings Hub

- **Visual Niri Compositor Configurator:** Full graphical editors for keybindings, layout dimensions, gesture inputs, animation curves, window rules, and raw KDL files.
- **Shell Customization:** Granular controls for bar density, widget layout, launcher prefixes, OSD timeouts, wallpaper engine paths, and animations.
- **Biometric Security Settings:** Direct facial authentication enrollment, model refresh, and verification management via Howdy.
- **Diagnostics & Cache Pruning:** Deep inspection of system dependencies, active systemd user services, and single-click cache cleaners.

### 📅 Productivity & Rich Media Hub

- **Calendar & Agenda:** Full monthly calendar with event badges, quick date jumps, and local task lists.
- **Cloud Calendar Sync:** Optional two-way synchronization with Google Calendar and Google Tasks.
- **Live Weather Widget:** Real-time location-based weather tracking with animated atmospheric icons (rain, snow, clouds, thunder).
- **Synchronized Music Lyrics:** Real-time karaoke-style lyric scrolling synced with the active MPRIS music player.
- **Pomodoro & Countdown Timers:** Precision countdown dial with customizable timers and audio-visual alarms.

### 🎨 Wallpaper Engine & Material You Palette

- **Versatile Wallpaper Backends:** Support for static images, seamless video loops via `mpvpaper`, and interactive Steam Workshop projects via `linux-wallpaperengine`.
- **Steam Workshop Integration:** In-app Workshop explorer with real-time search, tag filtering, subscription management, download progress, and cancel/delete controls.
- **Wallhaven Online Explorer:** Browse top-rated static wallpapers, filter by resolution, aspect ratio, color palette, categories, purity (SFW/Sketchy/NSFW), and user collections.
- **Kinetic Transitions:** Cinematic Ken Burns zoom-and-fade transitions when switching wallpapers and videos.
- **Automated Theme Synchronization:** Automatic color palette generation via **Matugen**, distributing consistent Material Design 3 color tokens across Quickshell, GTK, Qt, VS Code, and terminal emulators.

### 📸 Screen Capture & Visual Privacy

- **Advanced Screenshot Editor:** Region selection, magnifier loupe, annotation tools (pencil, arrows, rectangles, text), pixelation/blur privacy tools, and color pickers.
- **Optical Character Recognition (OCR):** Instant text extraction from selected screen regions directly to the system clipboard.
- **High-Performance Screen Recorder:** Hardware-accelerated desktop recording with customizable codecs, bitrates, frame rates, microphone audio pass-through, and output paths.

### 🔔 iOS-Style Notification System

- **Lockscreen Notification Stacks:** Group notifications intelligently by application into multi-layer 3D stacks with counter badges.
- **Interactive Group Expansion:** Tap any stack on the lock screen to smoothly expand all individual notifications with fluid physics-based motion.
- **Swipe-to-Dismiss:** Horizontal flick gestures to dismiss individual cards or entire stacks with automatic reflow of surrounding elements.
- **Do Not Disturb & History Archive:** Configurable auto-dismiss timeouts, scheduled quiet hours, application blacklisting, and a searchable notification history center.

### 🔒 Security, Gestures & Power

- **Multi-Monitor Lock Screen:** Secure PAM-integrated lock surfaces across all attached displays with optional Howdy face authentication and clock widget.
- **Native Polkit Agent:** Elevation dialogs rendered natively within the shell's theme.
- **Edge-Swipe Gestures:** Interactive touchscreen and touchpad edge dragging to reveal the left and right control panels with 1:1 finger tracking.
- **Minimalist Power Hub:** Quick access to Shutdown, Reboot, Lock, Hibernate, Suspend, and Logout with fluid pill expansion and confirmation safeguards.

> and more features...

## Inspiration

SownteeShell takes inspiration from these open Linux desktop projects:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [end-4's Hyprland dots](https://github.com/end-4/dots-hyprland)
- [Caelestia Shell](https://github.com/caelestia-dots/shell)

Its foundation comes from the wider [Niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org/), and [Matugen](https://github.com/InioX/matugen) communities.

## Disclaimer

This is a personal and continuously evolving shell. It is shared as a showcase, with no promise that the complete environment will work on different hardware or match another user's workflow.
