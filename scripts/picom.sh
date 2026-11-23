#!/usr/bin/env bash
set -euo pipefail

config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
runtime_dir="${XDG_RUNTIME_DIR:?}/awesome"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/awesome"
display_name="${DISPLAY//[^[:alnum:]]/_}"
mkdir -p "$runtime_dir" "$cache_dir"
pid_file="$runtime_dir/picom-$display_name.pid"
exec 8>"$pid_file.lock"
flock 8

pid=""
if [[ -r "$pid_file" ]]; then
    read -r pid < "$pid_file" || true
fi
running=false
if [[ "$pid" =~ ^[0-9]+$ ]] && [[ -r "/proc/$pid/comm" ]] && [[ "$(cat "/proc/$pid/comm")" == picom ]]; then
    running=true
fi

case "${1:-start}" in
    start)
        if "$running"; then exit 0; fi
        ;;
    toggle)
        if [[ -f "$cache_dir/blur" ]] && grep -qx true "$cache_dir/blur"; then
            printf 'false\n' > "$cache_dir/blur"
        else
            printf 'true\n' > "$cache_dir/blur"
        fi
        if "$running"; then
            kill "$pid"
            for attempt in {1..50}; do
                if ! kill -0 "$pid" 2>/dev/null; then break; fi
                sleep 0.05
            done
            if kill -0 "$pid" 2>/dev/null; then
                printf 'Previous Picom process has not exited.\n' >&2
                exit 1
            fi
        fi
        ;;
    *) printf 'Usage: %s [start|toggle]\n' "$0" >&2; exit 2 ;;
esac

config="$config_dir/scripts/picom/picom_no_opacity.conf"
if [[ -f "$cache_dir/blur" ]] && grep -qx true "$cache_dir/blur"; then
    config="$config_dir/scripts/picom/picom.conf"
fi
picom --config "$config" >> "$runtime_dir/picom-$display_name.log" 2>&1 8>&- 9>&- &
pid=$!
printf '%s\n' "$pid" > "$pid_file"
sleep 0.3
kill -0 "$pid" 2>/dev/null
