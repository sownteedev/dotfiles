#!/usr/bin/env bash

bspc config border_width 0
bspc config window_gap 0

# Launch dunst notification daemon
dunst -config "$HOME"/.config/bspwm/rices/yoru/dunstrc &
