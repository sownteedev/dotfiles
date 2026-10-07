#!/usr/bin/env bash
set -u

source_output="${1:-}"
scaling="${2:-fit}"
shift 2 || true

if [[ -z "$source_output" || "$#" -eq 0 ]] || ! command -v wl-mirror >/dev/null 2>&1; then
    exit 2
fi

mirror_pids=()

cleanup() {
    trap - TERM INT EXIT
    for pid in "${mirror_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}

trap cleanup TERM INT EXIT

for target_output in "$@"; do
    wl-mirror "$source_output" \
        --fullscreen-output "$target_output" \
        --scaling "$scaling" \
        --title "SownteeShell Mirror — $target_output" &
    mirror_pids+=("$!")
done

wait
