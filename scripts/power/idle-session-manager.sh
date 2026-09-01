#!/usr/bin/env bash

# Apply the shell's swayidle-based dim, lock, display, and suspend policy.

set -eu

readonly ACTION="${1:-}"
readonly LOCK_TIMEOUT="${2:-600}"
readonly DISPLAY_TIMEOUT="${3:-600}"
readonly SUSPEND_TIMEOUT="${4:-0}"
readonly LOCK_BEFORE_SLEEP="${5:-true}"
readonly LOCKED_DISPLAY_TIMEOUT="${6:-60}"
readonly DIM_DURATION="${7:-5}"
readonly REQUESTED_SLEEP_ACTION="${8:-suspend}"
readonly RESPECT_INHIBITORS="${9:-true}"
readonly UNIT="quickshell-idle.service"
readonly SHELL_CONFIG="${HOME}/Dotfiles/quickshell/shell.qml"

sleep_capability() {
    local method="$1"
    local response

    response="$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "$method" 2>/dev/null || true)"
    case "$response" in
        *'"yes"'*) printf 'yes' ;;
        *'"challenge"'*) printf 'challenge' ;;
        *'"no"'*) printf 'no' ;;
        *'"na"'*) printf 'na' ;;
        *) printf 'unknown' ;;
    esac
}

hide_dim() {
    /usr/bin/timeout --signal=TERM 1s quickshell ipc -p "$SHELL_CONFIG" call idleDim hide >/dev/null 2>&1 || true
}

stop_unit() {
    systemctl --user stop "$UNIT" 2>/dev/null || true
    systemctl --user reset-failed "$UNIT" 2>/dev/null || true
}

case "$ACTION" in
    capabilities)
        printf '{"suspend":"%s","hibernate":"%s","suspend-then-hibernate":"%s"}\n' \
            "$(sleep_capability CanSuspend)" \
            "$(sleep_capability CanHibernate)" \
            "$(sleep_capability CanSuspendThenHibernate)"
        ;;
    apply)
        case "$REQUESTED_SLEEP_ACTION" in
            none|suspend|hibernate|suspend-then-hibernate)
                sleep_action="$REQUESTED_SLEEP_ACTION"
                ;;
            *)
                sleep_action="suspend"
                ;;
        esac

        stop_unit
        hide_dim

        ipc_command="/usr/bin/timeout --signal=TERM 1s quickshell ipc -p \"${SHELL_CONFIG}\" call"
        lock_command="${ipc_command} lockscreen lock >/dev/null"
        dim_show_command="${ipc_command} idleDim show >/dev/null"
        dim_hide_command="${ipc_command} idleDim hide >/dev/null"
        unlocked_lock_command="if [ \"\$(${ipc_command} lockscreen status 2>/dev/null | jq -r .locked)\" != true ]; then ${lock_command}; fi"
        unlocked_dim_command="if [ \"\$(${ipc_command} lockscreen status 2>/dev/null | jq -r .locked)\" != true ]; then ${dim_show_command}; fi"
        locked_dim_command="if [ \"\$(${ipc_command} lockscreen status 2>/dev/null | jq -r .locked)\" = true ]; then ${dim_show_command}; fi"
        locked_display_command="if [ \"\$(${ipc_command} lockscreen status 2>/dev/null | jq -r .locked)\" = true ]; then niri msg action power-off-monitors; fi"
        retry_face_command="${ipc_command} lockscreen retryFace >/dev/null"
        display_off_command="niri msg action power-off-monitors"
        swayidle_args=(/usr/bin/swayidle -w)

        if (( LOCKED_DISPLAY_TIMEOUT > 0 )); then
            locked_dim_timeout=$((LOCKED_DISPLAY_TIMEOUT - DIM_DURATION))
            if (( DIM_DURATION > 0 && locked_dim_timeout > 0 )); then
                swayidle_args+=(timeout "$locked_dim_timeout" "$locked_dim_command" resume "$dim_hide_command")
            fi
            swayidle_args+=(timeout "$LOCKED_DISPLAY_TIMEOUT" "$locked_display_command" resume "${dim_hide_command}; ${retry_face_command}")
        fi
        if [[ "$RESPECT_INHIBITORS" == true ]]; then
            if (( LOCK_TIMEOUT > 0 && LOCK_TIMEOUT == DISPLAY_TIMEOUT )); then
                display_off_command="${lock_command} && ${display_off_command}"
            elif (( LOCK_TIMEOUT > 0 )); then
                swayidle_args+=(timeout "$LOCK_TIMEOUT" "$unlocked_lock_command")
            fi
            if (( DISPLAY_TIMEOUT > 0 )); then
                unlocked_display_command="if [ \"\$(${ipc_command} lockscreen status 2>/dev/null | jq -r .locked)\" != true ]; then ${display_off_command}; fi"
                display_dim_timeout=$((DISPLAY_TIMEOUT - DIM_DURATION))
                if (( DIM_DURATION > 0 && display_dim_timeout > 0 )); then
                    swayidle_args+=(timeout "$display_dim_timeout" "$unlocked_dim_command" resume "$dim_hide_command")
                fi
                swayidle_args+=(timeout "$DISPLAY_TIMEOUT" "$unlocked_display_command" resume "${dim_hide_command}; ${retry_face_command}")
            fi
            if (( SUSPEND_TIMEOUT > 0 )) && [[ "$sleep_action" != none ]]; then
                swayidle_args+=(timeout "$SUSPEND_TIMEOUT" "systemctl ${sleep_action}")
            fi
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
        hide_dim
        ;;
    *)
        printf 'Usage: %s apply|disable|capabilities [lock] [display] [sleep] [lock-before-sleep] [locked-display] [dim-duration] [sleep-action] [respect-inhibitors]\n' "$0" >&2
        exit 2
        ;;
esac
