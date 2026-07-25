#!/usr/bin/env bash
FILE="$1"

if [[ ! -e "$FILE" ]]; then
    exit 1
fi

if [[ -d "$FILE" ]]; then
    eza -1 --color=always --icons=always "$FILE" 2>/dev/null || ls -la "$FILE"
    exit 0
fi

MIME=$(file -b --mime-type "$FILE")

case "$MIME" in
    image/*)
        if command -v chafa >/dev/null 2>&1; then
            # Force high-resolution symbols (braille/sextants) instead of blocky defaults
            chafa -f symbols --symbols all -c full -s "${FZF_PREVIEW_COLUMNS:-80}x${FZF_PREVIEW_LINES:-40}" "$FILE" 2>/dev/null
        else
            echo "🖼️ Image File: $FILE"
            echo "Please install chafa: sudo pacman -S chafa"
        fi
        ;;
    video/*)
        if command -v chafa >/dev/null 2>&1 && command -v ffmpegthumbnailer >/dev/null 2>&1; then
            ffmpegthumbnailer -i "$FILE" -o - -s 0 -c jpeg 2>/dev/null | chafa -f symbols --symbols all -c full -s "${FZF_PREVIEW_COLUMNS:-80}x${FZF_PREVIEW_LINES:-40}" - 2>/dev/null
        else
            echo "🎥 Video File: $FILE"
            echo "Please install ffmpegthumbnailer and chafa."
        fi
        ;;
    application/pdf)
        if command -v pdftotext >/dev/null 2>&1; then
            pdftotext "$FILE" - | head -n 100
        else
            echo "📄 PDF File: $FILE"
            echo "Please install poppler."
        fi
        ;;
    application/zip|application/x-tar|application/x-bzip2|application/x-gzip|application/x-xz)
        tar -tf "$FILE" 2>/dev/null | head -n 100
        ;;
    text/*|*)
        if command -v bat >/dev/null 2>&1; then
            bat --color=always --style=numbers,changes,header --line-range=:500 "$FILE"
        else
            less -R "$FILE" 2>/dev/null || cat "$FILE"
        fi
        ;;
esac
