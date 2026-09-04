#!/usr/bin/env bash

set -u

check_updates() {
    if ! command -v yay >/dev/null 2>&1; then
        printf '__YAY_MISSING__\n'
        return
    fi

    local repo_updates repo_status aur_updates aur_status
    if command -v checkupdates >/dev/null 2>&1; then
        repo_updates=$(checkupdates 2>&1)
        repo_status=$?
        if [[ $repo_status -eq 2 ]]; then
            repo_updates=""
            repo_status=0
        fi
    else
        repo_updates=$(yay -Qu --repo --color never 2>&1)
        repo_status=$?
        if [[ $repo_status -eq 1 && -z $repo_updates ]]; then
            repo_status=0
        fi
    fi

    aur_updates=$(yay -Qua --color never 2>&1)
    aur_status=$?
    if [[ $aur_status -eq 1 && -z $aur_updates ]]; then
        aur_status=0
    fi

    local flatpak_system_updates=""
    local flatpak_user_updates=""
    local flatpak_status=0
    if command -v flatpak >/dev/null 2>&1; then
        flatpak_system_updates=$(flatpak remote-ls --system --updates --columns=ref 2>/dev/null) || flatpak_status=$?
        if [[ $flatpak_status -eq 0 ]]; then
            flatpak_user_updates=$(flatpak remote-ls --user --updates --columns=ref 2>/dev/null) || flatpak_status=$?
        fi
    fi

    if [[ $repo_status -ne 0 || $aur_status -ne 0 || $flatpak_status -ne 0 ]]; then
        printf '__CHECK_FAILED__\n'
        return
    fi

    {
        printf '%s\n' "$repo_updates"
        printf '%s\n' "$aur_updates"
        printf '%s\n' "$flatpak_system_updates" | awk 'NF { print "flatpak-system:" $0 }'
        printf '%s\n' "$flatpak_user_updates" | awk 'NF { print "flatpak-user:" $0 }'
    } | awk 'NF && !seen[$1]++'
}

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
check)
    check_updates
    ;;
upgrade)
    upgrade_packages "${2:-}"
    ;;
*)
    printf 'Usage: %s {check|upgrade RESULT_FILE}\n' "$0" >&2
    exit 2
    ;;
esac
