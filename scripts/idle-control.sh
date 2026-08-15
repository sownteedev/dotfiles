#!/usr/bin/env bash

set -eu

readonly ACTION="${1:-}"
readonly LOCK_TIMEOUT="${2:-600}"
readonly DISPLAY_TIMEOUT="${3:-600}"
readonly SUSPEND_TIMEOUT="${4:-0}"
readonly LOCK_BEFORE_SLEEP="${5:-true}"
readonly LOCKED_DISPLAY_TIMEOUT="${6:-60}"
readonly UNIT="quickshell-idle.service"
readonly SHELL_CONFIG="${HOME}/Dotfiles/quickshell/shell.qml"

stop_unit() {
    systemctl --user stop "$UNIT" 2>/dev/null || true
    systemctl --user reset-failed "$UNIT" 2>/dev/null || true
}

case "$ACTION" in
    apply)
        stop_unit

        lock_command="quickshell ipc -p \"${SHELL_CONFIG}\" call lockscreen lock"
        locked_display_command="if [ \"\$(quickshell ipc -p \"${SHELL_CONFIG}\" call lockscreen status | jq -r .locked)\" = true ]; then niri msg action power-off-monitors; fi"
        retry_command="if [ \"\$(quickshell ipc -p \"${SHELL_CONFIG}\" call lockscreen status | jq -r .locked)\" = true ]; then quickshell ipc -p \"${SHELL_CONFIG}\" call lockscreen retryFace; fi"
        swayidle_args=(/usr/bin/swayidle -w)

        if (( LOCKED_DISPLAY_TIMEOUT > 0 )); then
            swayidle_args+=(timeout "$LOCKED_DISPLAY_TIMEOUT" "$locked_display_command" resume "$retry_command")
        fi
        if (( LOCK_TIMEOUT > 0 )); then
            swayidle_args+=(timeout "$LOCK_TIMEOUT" "$lock_command")
        fi
        if (( DISPLAY_TIMEOUT > 0 )); then
            swayidle_args+=(timeout "$DISPLAY_TIMEOUT" "niri msg action power-off-monitors")
        fi
        if (( SUSPEND_TIMEOUT > 0 )); then
            swayidle_args+=(timeout "$SUSPEND_TIMEOUT" "systemctl suspend")
        fi
        if [[ "$LOCK_BEFORE_SLEEP" == true ]]; then
            swayidle_args+=(before-sleep "$lock_command")
        fi

        systemd-run \
            --user \
            --quiet \
            --unit="$UNIT" \
            --collect \
            --property=KillMode=control-group \
            --description="Quickshell idle policy" \
            "${swayidle_args[@]}"
        ;;
    disable)
        stop_unit
        ;;
    *)
        printf 'Usage: %s apply|disable [lock] [display] [suspend] [lock-before-sleep] [locked-display]\n' "$0" >&2
        exit 2
        ;;
esac
