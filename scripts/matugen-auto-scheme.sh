#!/bin/sh

set -eu

SATURATION_THRESHOLD="0.15"
COLORED_PIXEL_THRESHOLD="0.15"
# Image/video thumbnails can differ by a few pixels between frames. Keep
# borderline near-monochrome frames from flipping the whole palette.
CLASSIFICATION_EPSILON="0.005"

usage() {
    printf 'Usage: %s [--config PATH] [--mode dark|light|auto] [--dry-run] [--json FORMAT] [--quiet] IMAGE\n' "$0" >&2
    exit 2
}

config_path=""
dry_run=false
json_format=""
mode="auto"
quiet=false
image_path=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config)
            [ "$#" -ge 2 ] || usage
            config_path=$2
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --mode)
            [ "$#" -ge 2 ] || usage
            mode=$2
            shift 2
            ;;
        --json)
            [ "$#" -ge 2 ] || usage
            json_format=$2
            shift 2
            ;;
        --quiet)
            quiet=true
            shift
            ;;
        -*)
            usage
            ;;
        *)
            [ -z "$image_path" ] || usage
            image_path=$1
            shift
            ;;
    esac
done

[ -n "$image_path" ] || usage

case "$mode" in
    auto|dark|light) ;;
    *) usage ;;
esac

scheme="scheme-tonal-spot"

if command -v magick >/dev/null 2>&1; then
    metrics=$(
        magick "$image_path" \
            -auto-orient \
            -thumbnail '128x128>' \
            -write mpr:base \
            -colorspace HSL \
            -channel G \
            -separate +channel \
            -write mpr:saturation \
            -print '%[fx:max(0,mean)] ' \
            +delete \
            mpr:saturation \
            -threshold 12% \
            -print '%[fx:mean] ' \
            +delete \
            mpr:base \
            -colorspace gray \
            -write mpr:lum \
            -print '%[fx:mean] ' \
            +delete \
            mpr:lum \
            -threshold 75% \
            -print '%[fx:mean]' \
            null: 2>/dev/null || true
    )

    mean_saturation=$(echo "$metrics" | awk '{print $1}')
    colored_fraction=$(echo "$metrics" | awk '{print $2}')
    mean_luminance=$(echo "$metrics" | awk '{print $3}')
    high_lum_fraction=$(echo "$metrics" | awk '{print $4}')

    if [ -n "$mean_saturation" ] && [ -n "$colored_fraction" ] &&
        awk -v mean="$mean_saturation" \
            -v colored="$colored_fraction" \
            -v mean_limit="$SATURATION_THRESHOLD" \
            -v colored_limit="$COLORED_PIXEL_THRESHOLD" \
            -v epsilon="$CLASSIFICATION_EPSILON" \
            'BEGIN { exit ! (mean < mean_limit && colored < colored_limit + epsilon) }'; then
        scheme="scheme-monochrome"
    fi

    if [ "$mode" = "auto" ] && [ -n "$mean_luminance" ] && [ -n "$high_lum_fraction" ]; then
        if awk -v lum="$mean_luminance" 'BEGIN { exit !(lum > 0.65) }'; then
            mode="light"
        else
            mode="dark"
        fi
    fi
fi

if [ "$mode" = "auto" ]; then
    color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)
    case "$color_scheme" in
        *prefer-light*) mode="light" ;;
        *) mode="dark" ;;
    esac
fi

set -- matugen
[ -z "$config_path" ] || set -- "$@" --config "$config_path"
set -- "$@" image "$image_path" --type "$scheme" --mode "$mode" --source-color-index 0
[ "$dry_run" = false ] || set -- "$@" --dry-run
[ -z "$json_format" ] || set -- "$@" --json "$json_format"
[ "$quiet" = false ] || set -- "$@" --quiet

exec "$@"
