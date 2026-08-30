#!/usr/bin/env sh
# Build and run the AirPods battery telemetry backend on demand.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache_root=${XDG_CACHE_HOME:-"$HOME/.cache"}/quickshell
source_file=$script_dir/../../backend/native/bluetooth/airpods_battery_monitor.cpp
binary_file=$cache_root/sownteeshell-airpods-battery

if [ ! -x "$binary_file" ] || [ "$source_file" -nt "$binary_file" ]; then
    mkdir -p "$cache_root"
    temporary_file=$binary_file.tmp.$$
    trap 'rm -f "$temporary_file"' EXIT HUP INT TERM
    c++ -std=c++17 -O2 -fPIC -no-pie -Wno-sfinae-incomplete \
        "$source_file" -o "$temporary_file" \
        $(pkg-config --cflags --libs Qt6Core Qt6Bluetooth)
    chmod 755 "$temporary_file"
    mv -f "$temporary_file" "$binary_file"
    trap - EXIT HUP INT TERM
fi

exec "$binary_file" "$@"
