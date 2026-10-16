#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    printf '%s\n' 'Run the greeter test as your desktop user, not root.' >&2
    exit 1
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
shell_dir="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
test_cache="${XDG_CACHE_HOME:-$HOME/.cache}/sownteeshell/greeter-test"
mkdir -p -m 0700 "$test_cache"

exec env -u GREETD_SOCK \
    SOWNTEE_GREETER_PAM_TEST=1 \
    GREETD_DEFAULT_USER="$(id -un)" \
    GREETD_SESSION_NAME=Niri \
    GREETD_THEME_PATH=/var/lib/sownteeshell/greeter/colors.json \
    GREETD_BACKGROUND_PATH=/var/lib/sownteeshell/greeter/background.json \
    GREETD_PROFILE_PATH=/var/lib/sownteeshell/greeter/profile.json \
    GREETD_SETTINGS_PATH=/var/lib/sownteeshell/greeter/settings.json \
    XDG_CACHE_HOME="$test_cache" \
    quickshell --no-duplicate --path "$shell_dir/widget/greeter"
