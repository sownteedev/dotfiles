# Instructions for `dotf/`

## Purpose

`dotf/` is the source-of-truth configuration tree.

Current top-level roles:

- `.config/`: user configuration, normally consumed under `$HOME/.config/`.
- `.fonts/`: user fonts.
- `.icons/`: user icon and cursor resources.
- `.walls/`: wallpaper and visual assets.
- `.root/`: resources intended for system-level destinations outside the user's home directory, such as GRUB and SDDM themes.

## Deployment rules

- Do not assume every item is deployed in the same way.
- Before changing deployment semantics, inspect `../install/.installconfigtheme` and any other scripts that reference the path.
- Preserve the existing choice between symlink, copy, generated file, and system install.
- Treat `.root/` as source material only; determine its actual destination from the installer before editing paths.
- Never silently convert a user-scoped resource into a system-scoped resource, or the reverse.
- Do not hardcode a username or a home path. Prefer `$HOME` and XDG variables in scripts where applicable.
- Preserve hidden directory names because deployment paths depend on them.

## Configuration rules

- Reuse existing shared theme, font, color, spacing, and path definitions before duplicating values.
- Search for references before renaming files, themes, directories, commands, or assets.
- Keep configuration compatible with the current Arch Linux + Niri environment unless the request explicitly changes that target.
- Do not commit caches, sockets, logs, temporary state, runtime-generated settings, or secrets.
- Do not rewrite binary assets, wallpapers, fonts, or icons unless the request specifically requires conversion or optimization.
- Preserve image dimensions, transparency, color profile, and file format unless changing them is part of the task.

## Cross-directory checks

When changing any path or resource, search:

- `../install/` for deployment logic and destination paths.
- `../quickshell/` for runtime references to wallpapers, fonts, icons, commands, and settings.

## Validation

Use read-only validation where possible:

- verify referenced source paths exist;
- inspect symlink/copy destinations encoded in the installer;
- check text configuration syntax with an appropriate parser or linter when already available;
- report system-level destinations without writing to them.

Do not deploy files into `$HOME`, `/etc`, `/usr`, `/boot`, or other live locations merely to validate an edit.
