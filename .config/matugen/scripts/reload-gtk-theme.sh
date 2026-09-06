#!/usr/bin/env bash
set -u

schema="org.gnome.desktop.interface"

if ! command -v gsettings >/dev/null 2>&1; then
    exit 0
fi

scheme=$(gsettings get "$schema" color-scheme 2>/dev/null || true)
scheme=${scheme#\'}
scheme=${scheme%\'}
scheme=${scheme:-prefer-dark}

if [[ "$scheme" == "prefer-dark" ]]; then
    alternate_scheme="prefer-light"
elif [[ "$scheme" == "prefer-light" ]]; then
    alternate_scheme="prefer-dark"
else
    alternate_scheme="prefer-dark"
fi

# Matugen replaces colors.css atomically, while an existing libadwaita process
# can keep the old imported stylesheet. Briefly crossing the real light/dark
# boundary makes GTK 4 rebuild its style cascade after the new file exists.
# "default" is not sufficient here because it still resolves to light when
# the active preference is light. GTK 3 is intentionally left alone because
# Chromium can latch onto a temporary fallback theme.
gsettings set "$schema" color-scheme "$alternate_scheme" 2>/dev/null || true
sleep 0.08
gsettings set "$schema" color-scheme "$scheme" 2>/dev/null || true
