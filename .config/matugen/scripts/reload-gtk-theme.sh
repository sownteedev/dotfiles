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
    alternate_scheme="default"
elif [[ "$scheme" == "prefer-light" ]]; then
    alternate_scheme="default"
else
    alternate_scheme="prefer-dark"
fi

# GTK 4/libadwaita watches color-scheme and reliably rebuilds its style
# cascade. GTK 3 is intentionally left alone because Chromium can latch onto
# the temporary fallback theme and ignore the restore notification.
gsettings set "$schema" color-scheme "$alternate_scheme" 2>/dev/null || true
sleep 0.08
gsettings set "$schema" color-scheme "$scheme" 2>/dev/null || true
