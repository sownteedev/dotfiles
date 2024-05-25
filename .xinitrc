#!/bin/sh

userresources=$HOME/.Xresources
if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

dbus-run-session awesome
source /etc/X11/xinit/xinitrc.d/50-systemd-user.sh
eval $(/usr/bin/gnome-keyring-daemon --start)
export SSH_AUTH_SOCK
mkdir -p "$HOME"/.local/share/keyrings
dbus-run-session pipewire &

xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
