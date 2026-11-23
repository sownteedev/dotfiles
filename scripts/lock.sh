#!/usr/bin/env bash
set -euo pipefail

awesome-client 'awesome.emit_signal("toggle::lock")' >/dev/null
ready=false
for attempt in {1..50}; do
    if awesome-client 'for display in screen do if not display.lock or not display.lock.visible or display.lock.y ~= display.geometry.y then return "not-ready" end end; return "lock-ready"' | grep -q '"lock-ready"'; then
        ready=true
        break
    fi
    sleep 0.1
done
if ! "$ready"; then
    printf 'Awesome lock screen did not become ready.\n' >&2
    exit 1
fi
if [[ "${XSS_SLEEP_LOCK_FD:-}" =~ ^[0-9]+$ ]]; then
    exec {XSS_SLEEP_LOCK_FD}>&-
fi
while awesome-client 'for display in screen do if display.lock and display.lock.visible then return "locked" end end; return "unlocked"' | grep -q '"locked"'; do
    sleep 0.5
done
