#!/usr/bin/env bash
# generate-token.sh — Generate a GitHub App installation access token
#
# Usage: generate-token.sh <app_id> <pem_path> <installation_id> <token_file>
#
# Generates a JWT from the App's private key, exchanges it for an installation
# token, and writes the token to the specified file with 600 permissions.
# Also writes metadata (expiry) to <token_file>.meta.
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or dependencies
#   2 - JWT generation failed
#   3 - Token exchange failed
set -euo pipefail

GITHUB_APP_ID="${1:?Usage: generate-token.sh <app_id> <pem_path> <installation_id> <token_file>}"
PEM_PATH="${2:?Missing pem_path}"
INSTALLATION_ID="${3:?Missing installation_id}"
TOKEN_FILE="${4:?Missing token_file}"

# Check dependencies
for cmd in openssl curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Required command not found: $cmd" >&2; exit 1; }
done

# --- Step 1: Generate JWT (valid for 10 minutes) ---

NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 540))

HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr -d '=' | tr '/+' '_-')
PAYLOAD=$(echo -n "{\"iss\":\"${GITHUB_APP_ID}\",\"iat\":${IAT},\"exp\":${EXP}}" | openssl base64 -e -A | tr -d '=' | tr '/+' '_-')

SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | \
  openssl dgst -sha256 -sign "$PEM_PATH" -binary | \
  openssl base64 -e -A | tr -d '=' | tr '/+' '_-') || {
  echo "Failed to sign JWT with PEM key" >&2
  exit 2
}

JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# --- Step 2: Exchange JWT for installation token ---

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Token exchange failed (HTTP $HTTP_CODE): $BODY" >&2
  exit 3
fi

TOKEN=$(echo "$BODY" | jq -r '.token // empty')
EXPIRES_AT=$(echo "$BODY" | jq -r '.expires_at // empty')
PERMISSIONS=$(echo "$BODY" | jq -c '.permissions // {}')

if [[ -z "$TOKEN" ]]; then
  echo "No token in response: $BODY" >&2
  exit 3
fi

# --- Step 3: Write token and metadata ---

mkdir -p "$(dirname "$TOKEN_FILE")"
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

# Write metadata for status checks
cat > "${TOKEN_FILE}.meta" <<METAEOF
{
  "expires_at": "$EXPIRES_AT",
  "app_id": "$GITHUB_APP_ID",
  "installation_id": "$INSTALLATION_ID",
  "permissions": $PERMISSIONS,
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
METAEOF
chmod 600 "${TOKEN_FILE}.meta"

echo "GitHub App token generated (expires: ${EXPIRES_AT})"
