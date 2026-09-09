#!/usr/bin/env bash
set -euo pipefail

# Deploy SownteeShell Greeter from repository to system (/usr/share/sownteeshell/greeter)
# Mirroring the deploy logic from install/.installconfigtheme:install_greetd()

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
sownteeshell_dir="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
dotfiles_dir="$(CDPATH= cd -- "$sownteeshell_dir/.." && pwd)"

greeter_source="$sownteeshell_dir/widget/greeter"
greeter_install_dir="/usr/share/sownteeshell/greeter"
greeter_theme_dir="/var/lib/sownteeshell/greeter"
greeter_runtime_dir="$greeter_theme_dir/runtime"
greetd_pam_source="$dotfiles_dir/dotf/.root/greetd/pam/greetd"
[ -f "$greetd_pam_source" ] || greetd_pam_source="$dotfiles_dir/.root/greetd/pam/greetd"

core_manifest="$sownteeshell_dir/backend/rust/core-daemon/Cargo.toml"
core_target_dir="$sownteeshell_dir/backend/rust/core-daemon/target"
core_binary="$core_target_dir/release/sownteeshell-core"
greeter_core_binary="/usr/lib/sownteeshell/sownteeshell-core"

# Check if running in privileged mode (invoked via pkexec)
if [ "${1:-}" = "--privileged" ]; then
    target_user="${2:-}"
    if [ -z "$target_user" ]; then
        echo "[!] Missing target user in privileged mode" >&2
        exit 1
    fi

    echo "[*] Deploying SownteeShell Greeter files to $greeter_install_dir..."
    install -d -m 0755 "$greeter_install_dir" /etc/greetd /etc/pam.d

    # Deploy core daemon binary if built
    if [ -x "$core_binary" ]; then
        install -D -m 0755 "$core_binary" "$greeter_core_binary"
    fi

    # Set up theme directory permissions
    install -d -o "$target_user" -g greeter -m 2750 "$greeter_theme_dir"
    chown "$target_user:greeter" "$greeter_theme_dir"
    chmod 2750 "$greeter_theme_dir"
    find "$greeter_theme_dir" -maxdepth 1 -type f -exec chown "$target_user:greeter" {} + 2>/dev/null || true
    find "$greeter_theme_dir" -maxdepth 1 -type f -exec chmod 0640 {} + 2>/dev/null || true

    # Set up greeter runtime directory
    install -d -o greeter -g greeter -m 0700 \
        "$greeter_runtime_dir" \
        "$greeter_runtime_dir/cache" \
        "$greeter_runtime_dir/config" \
        "$greeter_runtime_dir/data"
    chown -R greeter:greeter "$greeter_runtime_dir"
    find "$greeter_runtime_dir" -type d -exec chmod 0700 {} +

    # Synchronize greeter QML files (mirroring .installconfigtheme line 599)
    rsync -a --delete "$greeter_source/" "$greeter_install_dir/"
    chown -R root:root "$greeter_install_dir"
    find "$greeter_install_dir" -type d -exec chmod 0755 {} +
    find "$greeter_install_dir" -type f -exec chmod 0644 {} +

    # Install greetd PAM configuration if present
    if [ -f "$greetd_pam_source" ]; then
        install -m 0644 "$greetd_pam_source" /etc/pam.d/greetd
    fi

    # Ensure /etc/greetd/config.toml is configured properly
    config_temp=$(mktemp /tmp/sownteeshell-greetd-config.XXXXXX)
    cat > "$config_temp" << EOF
[terminal]
vt = 1

[default_session]
command = "env HOME=$greeter_runtime_dir XDG_CACHE_HOME=$greeter_runtime_dir/cache XDG_CONFIG_HOME=$greeter_runtime_dir/config XDG_DATA_HOME=$greeter_runtime_dir/data GREETD_DEFAULT_USER=$target_user GREETD_SESSION_NAME=Niri GREETD_THEME_PATH=$greeter_theme_dir/colors.json GREETD_BACKGROUND_PATH=$greeter_theme_dir/background.json GREETD_PROFILE_PATH=$greeter_theme_dir/profile.json GREETD_SETTINGS_PATH=$greeter_theme_dir/settings.json SOWNTEE_CORE_BINARY=$greeter_core_binary systemd-cat --identifier=sownteeshell-greeter cage -d -s -m extend -- quickshell --no-color --path $greeter_install_dir"
user = "greeter"
EOF
    install -m 0644 "$config_temp" /etc/greetd/config.toml
    rm -f -- "$config_temp" 2>/dev/null || true

    systemctl enable greetd.service 2>/dev/null || true
    echo "[*] Greeter successfully deployed for next boot."
    exit 0
fi

# Non-privileged entry point:
if [ ! -f "$greeter_source/shell.qml" ] || [ ! -f "$greeter_source/qmldir" ]; then
    echo "[!] Greeter source is incomplete: $greeter_source" >&2
    exit 1
fi

target_user="${USER:-$(id -un)}"

# Build core daemon binary if missing or sources newer (as normal user)
if [ -f "$core_manifest" ] && command -v cargo >/dev/null 2>&1; then
    needs_build=false
    if [ ! -x "$core_binary" ]; then
        needs_build=true
    else
        for src in "$sownteeshell_dir/backend/rust/core-daemon/src"/*.rs; do
            if [ "$src" -nt "$core_binary" ]; then
                needs_build=true
                break
            fi
        done
    fi
    if [ "$needs_build" = true ]; then
        echo "[*] Building SownteeShell core daemon..."
        CARGO_TARGET_DIR="$core_target_dir" cargo build --release --locked --manifest-path "$core_manifest"
    fi
fi

# Invoke privileged deployment with pkexec
exec pkexec "$0" --privileged "$target_user"
