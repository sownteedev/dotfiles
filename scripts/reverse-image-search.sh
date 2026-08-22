#!/usr/bin/env bash

set -u

readonly IMAGE_PATH="${1:-}"
readonly IMAGE_WIDTH="${2:-0}"
readonly IMAGE_HEIGHT="${3:-0}"
readonly LENS_HOME="https://lens.google.com/"
HTML_PATH=""

cleanup() {
    if [[ -n "$IMAGE_PATH" ]]; then
        rm -f -- "$IMAGE_PATH"
    fi
    if [[ -n "$HTML_PATH" ]]; then
        rm -f -- "$HTML_PATH"
    fi
}

open_url() {
    local url="$1"

    command -v xdg-open >/dev/null 2>&1 || return 1
    xdg-open "$url" >/dev/null 2>&1 &
}

open_manual_fallback() {
    local copied=false

    if command -v wl-copy >/dev/null 2>&1 && wl-copy --type image/png < "$IMAGE_PATH"; then
        copied=true
    fi
    if ! open_url "$LENS_HOME"; then
        printf 'Could not open Google Lens\n' >&2
        return 1
    fi
    if [[ "$copied" == true ]]; then
        printf 'fallback\n'
        return 0
    fi

    printf 'Could not upload or copy the image\n' >&2
    return 1
}

create_upload_page() {
    command -v python3 >/dev/null 2>&1 || return 1
    HTML_PATH="$(mktemp --suffix=.html /tmp/quickshell-google-lens-XXXXXX)" || return 1

    python3 - "$IMAGE_PATH" "$HTML_PATH" "$IMAGE_WIDTH" "$IMAGE_HEIGHT" <<'PY'
import base64
import html
import sys
import time
from pathlib import Path

image_path = Path(sys.argv[1])
html_path = Path(sys.argv[2])
width = max(1, int(sys.argv[3]))
height = max(1, int(sys.argv[4]))
payload = base64.b64encode(image_path.read_bytes()).decode("ascii")
endpoint = f"https://lens.google.com/v3/upload?stcs={int(time.time() * 1000)}"

document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="referrer" content="no-referrer">
  <title>Opening Google Lens…</title>
</head>
<body>
  <form id="lens-form" action="{html.escape(endpoint, quote=True)}" method="post" enctype="multipart/form-data">
    <input id="lens-image" name="encoded_image" type="file" hidden>
    <input name="processed_image_dimensions" type="hidden" value="{width},{height}">
  </form>
  <script>
    (async () => {{
      const response = await fetch("data:image/png;base64,{payload}");
      const blob = await response.blob();
      const transfer = new DataTransfer();
      transfer.items.add(new File([blob], "screenshot.png", {{ type: "image/png" }}));
      document.getElementById("lens-image").files = transfer.files;
      document.getElementById("lens-form").submit();
    }})().catch(() => {{
      document.body.textContent = "Could not prepare Google Lens. Return to the screenshot editor and try again.";
    }});
  </script>
</body>
</html>
"""

html_path.write_text(document, encoding="utf-8")
PY
}

trap cleanup EXIT

if [[ -z "$IMAGE_PATH" || ! -s "$IMAGE_PATH" ]]; then
    printf 'Screenshot image is unavailable\n' >&2
    exit 2
fi

if ! create_upload_page; then
    open_manual_fallback
    exit $?
fi

if ! open_url "$HTML_PATH"; then
    open_manual_fallback
    exit $?
fi

# The browser only needs the local page long enough to parse it. Let a detached
# cleanup remove the embedded screenshot after the navigation has started.
nohup sh -c 'sleep 15; rm -f -- "$1"' google-lens-cleanup "$HTML_PATH" >/dev/null 2>&1 &
HTML_PATH=""
printf 'opened\n'
