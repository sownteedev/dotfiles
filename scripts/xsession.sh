#!/usr/bin/env bash
set -euo pipefail

config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=awesome XDG_SESSION_DESKTOP=awesome DESKTOP_SESSION=awesome
export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx
export GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11 MOZ_ENABLE_WAYLAND=0
unset WAYLAND_DISPLAY WAYLAND_SOCKET

AWESOME_PAM_MODULE="${XDG_CACHE_HOME:-$HOME/.cache}/awesome/lua51/liblua_pam.so" \
    luajit -e 'local loader = assert(package.loadlib(os.getenv("AWESOME_PAM_MODULE"), "luaopen_liblua_pam")); assert(type(loader().auth_current_user) == "function")'

for script in /etc/X11/xinit/xinitrc.d/*.sh; do
    if [[ -x "$script" ]]; then . "$script"; fi
done
systemctl --user unset-environment WAYLAND_DISPLAY WAYLAND_SOCKET || true
dbus-update-activation-environment --systemd \
    DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION \
    GTK_IM_MODULE QT_IM_MODULE XMODIFIERS GDK_BACKEND QT_QPA_PLATFORM SDL_VIDEODRIVER MOZ_ENABLE_WAYLAND

xrandr --output DP-0 --mode 2560x1600 --rate 165.02
if [[ -f "$HOME/.Xresources" ]]; then
    xrdb -merge "$HOME/.Xresources"
fi
exec awesome --config "$config_dir/rc.lua"
