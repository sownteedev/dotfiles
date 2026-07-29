#!/bin/sh

set -eu

SATURATION_THRESHOLD="0.15"
COLORED_PIXEL_THRESHOLD="0.15"

usage() {
    printf 'Usage: %s [--config PATH] [--dry-run] [--json FORMAT] [--quiet] IMAGE\n' "$0" >&2
    exit 2
}

config_path=""
dry_run=false
json_format=""
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

scheme="scheme-tonal-spot"

if command -v magick >/dev/null 2>&1; then
    metrics=$(
        magick "$image_path" \
            -auto-orient \
            -thumbnail '128x128>' \
            -colorspace HSL \
            -channel G \
            -separate +channel \
            -write mpr:saturation \
            -print '%[fx:max(0,mean)] ' \
            +delete \
            mpr:saturation \
            -threshold 12% \
            -print '%[fx:mean]' \
            null: 2>/dev/null || true
    )

    mean_saturation=${metrics%% *}
    colored_fraction=${metrics#* }

    if [ -n "$mean_saturation" ] && [ -n "$colored_fraction" ] &&
        awk -v mean="$mean_saturation" \
            -v colored="$colored_fraction" \
            -v mean_limit="$SATURATION_THRESHOLD" \
            -v colored_limit="$COLORED_PIXEL_THRESHOLD" \
            'BEGIN { exit ! (mean < mean_limit && colored < colored_limit) }'; then
        scheme="scheme-monochrome"
    fi
fi

set -- matugen
[ -z "$config_path" ] || set -- "$@" --config "$config_path"
set -- "$@" image "$image_path" --type "$scheme" --source-color-index 0
[ "$dry_run" = false ] || set -- "$@" --dry-run
[ -z "$json_format" ] || set -- "$@" --json "$json_format"
[ "$quiet" = false ] || set -- "$@" --quiet

exec "$@"
