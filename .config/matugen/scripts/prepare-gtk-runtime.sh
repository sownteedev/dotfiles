#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dotfiles_config=$(cd -- "$script_dir/../.." && pwd)

# Theme selectors may replace gtk.css with a generated file or a link into
# /usr/share. Restore our stable entrypoint before Matugen writes colors.css.
for version in gtk-3.0 gtk-4.0; do
    runtime_dir="$config_home/$version"
    wrapper="$dotfiles_config/$version/gtk.css"
    settings_wrapper="$dotfiles_config/$version/settings.ini"
    target="$runtime_dir/gtk.css"
    palette="$runtime_dir/colors.css"
    settings_target="$runtime_dir/settings.ini"

    mkdir -p "$runtime_dir"
    if [[ ! -L "$target" ]] || [[ "$(readlink -f "$target" 2>/dev/null || true)" != "$(readlink -f "$wrapper")" ]]; then
        rm -f "$target"
        ln -s "$wrapper" "$target"
    fi
    if [[ "$version" == "gtk-4.0" ]]; then
        if [[ ! -L "$settings_target" ]] || [[ "$(readlink -f "$settings_target" 2>/dev/null || true)" != "$(readlink -f "$settings_wrapper")" ]]; then
            rm -f "$settings_target"
            ln -s "$settings_wrapper" "$settings_target"
        fi
    else
        settings_temp=$(mktemp "$runtime_dir/.settings.ini.XXXXXX")
        cp -L -- "$settings_wrapper" "$settings_temp"
        mv -f -- "$settings_temp" "$settings_target"
    fi

    # Never let Matugen follow a theme-manager symlink into a system theme.
    if [[ -L "$palette" ]]; then
        rm -f "$palette"
    fi
done
