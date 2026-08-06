# Instructions for `quickshell/`

## Purpose and architecture

This directory is a Quickshell QML desktop shell, not a collection of isolated snippets.

Important roles:

- `shell.qml`: application entry point and top-level orchestration.
- `Config.qml`: shared runtime configuration and persisted settings interface.
- `StateManager.qml`: shared UI/session state and panel/window coordination.
- `components/`: reusable low-level UI components.
- `widget/`: user-facing shell surfaces such as bar, desktop, notifications, OSD, capture, and related UI.
- `service/`: system and feature services.
- `backend/`: non-visual implementation and data logic.
- `plugin/`: native or extension code.
- `scripts/`: helper and system-integration scripts.
- `assets/`: static visual resources.
- `qmldir`: module and singleton declarations.

## Change placement

Before editing, trace the behavior through the appropriate layers:

1. Reference libs first from [Quickshell v0.3.0 types](https://quickshell.org/docs/v0.3.0/types/)
2. entry point or owning widget;
3. reusable component;
4. `StateManager.qml` for shared state and open/close coordination;
5. `Config.qml` for shared or persisted settings;
6. service/backend for system interaction or data;
7. scripts/plugins for external integration.

Put the fix in the narrowest correct layer. Do not embed backend or shell-command logic in a visual component when an existing service/backend abstraction owns it.

## QML rules

- Preserve existing imports, module boundaries, singleton usage, naming conventions, and formatting style.
- Reuse existing components, theme values, animations, typography, and spacing before adding duplicates.
- Prefer shared configuration properties over hardcoded values repeated across widgets.
- Avoid hardcoded monitor names, resolutions, absolute user paths, or assumptions about one screen.
- Preserve `Quickshell.screens`, `Variants`, per-screen delegates, and multi-monitor behavior when touching screen-aware UI.
- Preserve lazy-loader and state-manager behavior when changing panels, settings, lock screen, or other windows.
- Check IDs, required properties, signals, aliases, loader lifecycles, and import paths after refactors.
- Update `qmldir` when adding, removing, renaming, or changing the singleton status of module-visible QML types.
- Do not weaken lock-screen or authentication behavior for visual convenience.
- Avoid unnecessary polling when a signal, binding, watcher, or existing service can provide updates.

## Assets and system integration

- Search `../dotf/` before duplicating wallpapers, fonts, icons, or theme resources.
- Search `../install/` before adding a required package, service, binary, permission, or system path.
- When introducing a new runtime dependency, update the correct required or optional installer package group.
- Do not place secrets or private API values in source defaults. Keep shareable defaults empty or non-sensitive.

## Validation

- Prefer static inspection and targeted QML validation tools already installed in the environment.
- Use `qmllint` or `qmlformat` only when available and compatible with the project's imports.
- Do not restart the user's active Quickshell session automatically.
- Do not launch full-screen, lock-screen, capture, recording, authentication, or power actions during validation.
- Explain the exact manual reload/test path for the changed surface.
