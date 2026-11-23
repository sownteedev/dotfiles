#!/usr/bin/env bash
set -euo pipefail

config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'Start this session from Greetd or a text TTY, not inside another desktop.\n' >&2
    exit 1
fi
server_args=(-keeptty)
if [[ "${XDG_VTNR:-}" =~ ^[0-9]+$ ]]; then
    server_args+=("vt$XDG_VTNR")
fi
exec startx "$config_dir/scripts/xsession.sh" -- "${server_args[@]}"
