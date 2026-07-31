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
    target="$runtime_dir/gtk.css"
    palette="$runtime_dir/colors.css"

    mkdir -p "$runtime_dir"
    if [[ ! -L "$target" ]] || [[ "$(readlink -f "$target" 2>/dev/null || true)" != "$(readlink -f "$wrapper")" ]]; then
        rm -f "$target"
        ln -s "$wrapper" "$target"
    fi

    # Never let Matugen follow a theme-manager symlink into a system theme.
    if [[ -L "$palette" ]]; then
        rm -f "$palette"
    fi
done
