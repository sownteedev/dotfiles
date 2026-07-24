#!/usr/bin/env bash
set -euo pipefail

gtk4_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"
mkdir -p "$gtk4_dir"

# Theme selectors such as nwg-look may replace these files with links to
# /usr/share. Matugen must never follow those links and write into a
# system-owned theme.
for file in gtk.css gtk-dark.css; do
    path="$gtk4_dir/$file"
    if [[ -L "$path" ]]; then
        rm -f "$path"
    fi
done
