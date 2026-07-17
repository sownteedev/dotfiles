#!/bin/bash
# Google Calendar OAuth Setup (sownteedev)
# Automatically reads credentials from Global.ts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_TS="$SCRIPT_DIR/../Global.ts"
TOKEN_FILE="$HOME/Dotfiles/dotf/ags/google-calendar-token.json"
MODE="${1:-interactive}"
AUTH_CODE_INPUT="${2:-}"

echo "=== Google Calendar OAuth Setup ==="
echo ""

# Extract credentials from Global.ts
if [[ ! -f "$GLOBAL_TS" ]]; then
    echo "Error: Global.ts not found at $GLOBAL_TS"
    exit 1
fi

# Parse clientId and clientSecret from Global.ts (handles multi-line format)
# Remove newlines and extra spaces, then extract values
GLOBAL_CONTENT=$(tr -d '\n' < "$GLOBAL_TS" | tr -s ' ')
CLIENT_ID=$(echo "$GLOBAL_CONTENT" | grep -oP 'clientId:\s*"\K[^"]*' || true)
CLIENT_SECRET=$(echo "$GLOBAL_CONTENT" | grep -oP 'clientSecret:\s*"\K[^"]*' || true)

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
    echo "Error: Could not find clientId or clientSecret in Global.ts"
    echo "Please update Global.ts with your OAuth credentials first."
    exit 1
fi

echo "✓ Found credentials in Global.ts"
echo "  Client ID: ${CLIENT_ID:0:20}..."
echo ""

REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
# Calendar + Tasks (Tasks cần bật API trong Google Cloud Console)
SCOPE="https://www.googleapis.com/auth/calendar%20https://www.googleapis.com/auth/tasks"

AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=${SCOPE}&access_type=offline&prompt=consent"

if [[ "$MODE" != "--auth-code" ]]; then
    echo "Opening browser for authentication..."
    echo ""

    # Try to open browser
    if command -v xdg-open &>/dev/null; then
        xdg-open "$AUTH_URL" 2>/dev/null &
    elif command -v open &>/dev/null; then
        open "$AUTH_URL" 2>/dev/null &
    else
        echo "Could not open browser automatically."
        echo "Visit this URL manually:"
        echo ""
        echo "$AUTH_URL"
        echo ""
    fi
fi

if [[ "$MODE" == "--open-only" ]]; then
    echo "Opened authentication URL. Paste code in UI and press Done."
    exit 0
fi

if [[ "$MODE" == "--auth-code" ]]; then
    AUTH_CODE="$AUTH_CODE_INPUT"
else
    read -rp "Enter the authorization code: " AUTH_CODE
fi

if [[ -z "$AUTH_CODE" ]]; then
    echo "Error: Authorization code is required!"
    exit 1
fi

echo ""
echo "Exchanging code for tokens..."

TOKEN_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "code=${AUTH_CODE}" \
    -d "grant_type=authorization_code" \
    -d "redirect_uri=${REDIRECT_URI}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')
EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in // 3600')

if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "Error: Failed to get access token!"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

# Calculate expiry timestamp
EXPIRES_AT=$(($(date +%s) + EXPIRES_IN))

# Ensure directory exists
mkdir -p "$(dirname "$TOKEN_FILE")"

# Save tokens
cat > "$TOKEN_FILE" << EOF
{
    "client_id": "${CLIENT_ID}",
    "client_secret": "${CLIENT_SECRET}",
    "access_token": "${ACCESS_TOKEN}",
    "refresh_token": "${REFRESH_TOKEN}",
    "expires_at": ${EXPIRES_AT}
}
EOF

chmod 600 "$TOKEN_FILE"

echo ""
echo "✅ Success! Tokens saved to $TOKEN_FILE"
echo ""
echo "Restart AGS to use Google Calendar integration."
