#!/bin/sh

# Generate a Material You theme from a wallpaper and optional metadata.

set -eu

SATURATION_THRESHOLD="0.15"
COLORED_PIXEL_THRESHOLD="0.15"
# Image/video thumbnails can differ by a few pixels between frames. Keep
# borderline near-monochrome frames from flipping the whole palette.
CLASSIFICATION_EPSILON="0.005"
# Keep truly gray images deterministic, but prefer a visible colored detail
# (at least 0.5% of the thumbnail) when the wallpaper has one.
MONO_ACCENT_FALLBACK="#7188b8"
MONO_ACCENT_MIN_FRACTION="0.005"

usage() {
    printf 'Usage: %s [--config PATH] [--mode dark|light|auto] [--metadata-json JSON] [--dry-run] [--json FORMAT] [--quiet] IMAGE\n' "$0" >&2
    exit 2
}

config_path=""
dry_run=false
json_format=""
mode="auto"
metadata_json='{"theme_source":""}'
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
        --metadata-json)
            [ "$#" -ge 2 ] || usage
            metadata_json=$2
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
        mode="dark"
    fi
fi

if [ "$mode" = "auto" ]; then
    color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)
    case "$color_scheme" in
        *prefer-light*) mode="light" ;;
        *) mode="dark" ;;
    esac
fi

export SOWNTEESHELL_THEME_MODE="$mode"

accent_overrides=""
if [ "$scheme" = "scheme-monochrome" ] && command -v jq >/dev/null 2>&1; then
    set -- matugen
    [ -z "$config_path" ] || set -- "$@" --config "$config_path"
    if awk -v colored="$colored_fraction" -v minimum="$MONO_ACCENT_MIN_FRACTION" \
        'BEGIN { exit ! (colored >= minimum) }'; then
        set -- "$@" image "$image_path" --source-color-index 0 --fallback-color "$MONO_ACCENT_FALLBACK"
    else
        set -- "$@" color hex "$MONO_ACCENT_FALLBACK"
    fi

    # A dry run never writes templates or runs application hooks. Copy entire
    # MD3 role families, including on-colors and fixed roles for both modes;
    # Matugen merges these before rendering JSON *and* application templates.
    if accent_json=$("$@" --type scheme-tonal-spot --mode "$mode" --dry-run --json hex --quiet) &&
        accent_overrides=$(printf '%s' "$accent_json" | jq -ce '
            {colors: (.colors | with_entries(select(.key | test("^(on_)?(secondary|tertiary)($|_)")))),
             palettes: (.palettes | {secondary, tertiary})}
            | select(.colors.secondary.default.color and .colors.on_secondary.default.color
                and .colors.tertiary.default.color and .colors.on_tertiary.default.color)
        '); then
        :
    else
        accent_overrides=""
        printf '%s\n' 'Could not generate soft accents; keeping the monochrome palette.' >&2
    fi
fi

set -- matugen
[ -z "$config_path" ] || set -- "$@" --config "$config_path"
set -- "$@" image "$image_path" --type "$scheme" --mode "$mode" --source-color-index 0 --continue-on-error
[ -z "$accent_overrides" ] || set -- "$@" --import-json-string "$accent_overrides"
set -- "$@" --import-json-string "$metadata_json"
[ "$dry_run" = false ] || set -- "$@" --dry-run
[ -z "$json_format" ] || set -- "$@" --json "$json_format"
[ "$quiet" = false ] || set -- "$@" --quiet

exec "$@"
