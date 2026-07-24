#!/usr/bin/env bash
set -euo pipefail

schema="org.gnome.desktop.interface"
theme=$(gsettings get "$schema" gtk-theme | sed "s/^'//; s/'$//")
scheme=$(gsettings get "$schema" color-scheme | sed "s/^'//; s/'$//")

# GTK does not watch imported CSS files. Re-applying the current settings makes
# already running GTK3/GTK4 applications reload their Matugen palette.
gsettings set "$schema" gtk-theme ""
gsettings set "$schema" gtk-theme "$theme"

if [[ "$scheme" == "prefer-dark" ]]; then
    gsettings set "$schema" color-scheme prefer-light
else
    gsettings set "$schema" color-scheme prefer-dark
fi
gsettings set "$schema" color-scheme "$scheme"
