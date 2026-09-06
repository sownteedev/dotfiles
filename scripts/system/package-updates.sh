#!/usr/bin/env bash

set -u

upgrade_packages() {
    local result_file=${1:-}
    if [[ -z $result_file ]]; then
        printf 'Missing upgrade result path.\n' >&2
        return 2
    fi

    printf 'started\n' >"$result_file"
    printf 'Authenticate once to update repository, AUR, and Flatpak packages…\n\n'

    sudo -v
    local result=$?
    if [[ $result -eq 0 ]]; then
        yay --sudo /usr/bin/sudo --sudoloop -Syu --noconfirm \
            --answerclean None --answerdiff None --answeredit None
        result=$?
    fi

    if [[ $result -eq 0 && -x /usr/bin/flatpak ]]; then
        /usr/bin/flatpak update --user --assumeyes --noninteractive
        result=$?
    fi
    if [[ $result -eq 0 && -x /usr/bin/flatpak ]]; then
        sudo /usr/bin/flatpak update --system --assumeyes --noninteractive
        result=$?
    fi

    printf '%s\n' "$result" >"$result_file"
    printf '\n'
    if [[ $result -eq 0 ]]; then
        printf 'Upgrade complete.\n'
    else
        printf 'Upgrade failed (exit %s).\n' "$result"
    fi
    printf 'Press any key to close…'
    read -r -s -n 1
    return "$result"
}

case ${1:-} in
upgrade)
    upgrade_packages "${2:-}"
    ;;
*)
    printf 'Usage: %s upgrade RESULT_FILE\n' "$0" >&2
    exit 2
    ;;
esac
