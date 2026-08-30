#!/usr/bin/env bash

# Manage the user-scoped idle inhibitor used by Caffeine mode.

set -eu

readonly ACTION="${1:-}"
readonly UNIT="quickshell-caffeine-inhibitor.service"
readonly LEGACY_PATTERN='^/usr/bin/systemd-inhibit --what=idle --mode=block --who=Quickshell --why=Caffeine mode is active sleep infinity$'

cleanup_legacy_inhibitors() {
    local child_pid
    local inhibitor_pid

    while IFS= read -r inhibitor_pid; do
        while IFS= read -r child_pid; do
            kill -TERM "$child_pid" 2>/dev/null || true
        done < <(pgrep -P "$inhibitor_pid" || true)
        kill -TERM "$inhibitor_pid" 2>/dev/null || true
    done < <(pgrep -u "$(id -u)" -f "$LEGACY_PATTERN" || true)
}

case "$ACTION" in
    enable)
        if systemctl --user start "$UNIT" 2>/dev/null; then
            exit 0
        fi

        cleanup_legacy_inhibitors
        systemd-run \
            --user \
            --quiet \
            --unit="$UNIT" \
            --collect \
            --property=KillMode=control-group \
            --description="Quickshell Caffeine inhibitor" \
            /usr/bin/systemd-inhibit \
            --what=idle \
            --mode=block \
            --who=Quickshell \
            "--why=Caffeine mode is active" \
            /usr/bin/sleep infinity
        ;;
    disable)
        systemctl --user stop "$UNIT" 2>/dev/null || true
        cleanup_legacy_inhibitors
        ;;
    *)
        printf 'Usage: %s enable|disable\n' "$0" >&2
        exit 2
        ;;
esac
