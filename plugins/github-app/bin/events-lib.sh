#!/usr/bin/env bash
# events-lib.sh — Shared library for GitHub events fetch/cursor/delivery logic.
#
# Sourced by both events-fetch.sh (hook-driven delivery) and events-monitor.sh
# (manual/CLI watcher). Provides:
#   - Plugin settings loading (best-effort, no hard dep on shared-lib)
#   - Token refresh via token-check.sh
#   - GitHub Events REST API fetch
#   - Chronological cursor management (newest-event-id stop-marker)
#   - Hook state file management (last_seen_id + last_fetch_ts)
#   - Event formatting
#   - Output routing (eventsDelivery modes: disabled / file / user / both / summary)
#
# Guard against double-source:
if [ "${_EVENTS_LIB_LOADED:-}" = "true" ]; then return 0; fi
_EVENTS_LIB_LOADED=true

set -uo pipefail

# ---------------------------------------------------------------------------
# Caller must set before sourcing:
#   PLUGIN_NAME="github-app"
#   SCRIPT_DIR=/path/to/bin          (so we can find token-check.sh)
#   CLAUDE_PLUGIN_DATA=...           (plugin data directory)
# ---------------------------------------------------------------------------

# ---- Paths ----------------------------------------------------------------

: "${PLUGIN_NAME:=github-app}"
: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/github-app-ai-mktpl}"
: "${SCRIPT_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

TOKEN_FILE="${GITHUB_TOKEN_FILE:-${CLAUDE_PLUGIN_DATA}/github-token}"
META_FILE="${TOKEN_FILE}.meta"

# State file: persists cursor (last seen event id) and last-fetch UNIX timestamp.
EVENTS_STATE_FILE="${CLAUDE_PLUGIN_DATA}/events-hook-state.json"
# Audit log: append-only delivery record (written for all modes except disabled).
EVENTS_AUDIT_LOG="${CLAUDE_PLUGIN_DATA}/events-delivery.log"

DEFAULT_PER_PAGE=50

mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || true

# ---- Shared-lib best-effort load -----------------------------------------

_evlib_setting_interval=""
_evlib_setting_repo=""
_evlib_setting_delivery=""
_evlib_setting_stop_timeout=""
_evlib_setting_stop_notice=""

_evlib_load_plugin_settings() {
  local sld
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    sld="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
  else
    sld="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
  fi
  [ -f "$sld/plugin-config-read.sh" ] || return 1
  # shellcheck source=/dev/null
  source "$sld/plugin-config-read.sh" 2>/dev/null || return 1
  _evlib_setting_interval="$(plugin_get_config "eventsPollIntervalSeconds" "" 2>/dev/null || true)"
  _evlib_setting_repo="$(plugin_get_config "eventsRepo" "" 2>/dev/null || true)"
  _evlib_setting_delivery="$(plugin_get_config "eventsDelivery" "" 2>/dev/null || true)"
  _evlib_setting_stop_timeout="$(plugin_get_config "eventsStopTimeoutSeconds" "" 2>/dev/null || true)"
  _evlib_setting_stop_notice="$(plugin_get_config "eventsStopNoticeSeconds" "" 2>/dev/null || true)"
  return 0
}
_evlib_load_plugin_settings || true

# ---- Config resolution helpers -------------------------------------------
# Precedence: env var > plugin setting > default

evlib_interval() {
  echo "${GITHUB_APP_EVENTS_INTERVAL:-${_evlib_setting_interval:-15}}"
}

evlib_repo() {
  echo "${GITHUB_APP_EVENTS_REPO:-${_evlib_setting_repo:-}}"
}

evlib_delivery() {
  # env var GITHUB_APP_EVENTS_DELIVERY overrides plugin setting
  local val="${GITHUB_APP_EVENTS_DELIVERY:-${_evlib_setting_delivery:-disabled}}"
  echo "$val"
}

evlib_stop_timeout() {
  echo "${GITHUB_APP_EVENTS_STOP_TIMEOUT:-${_evlib_setting_stop_timeout:-600}}"
}

evlib_stop_notice() {
  echo "${GITHUB_APP_EVENTS_STOP_NOTICE:-${_evlib_setting_stop_notice:-480}}"
}

evlib_per_page() {
  echo "${GITHUB_APP_EVENTS_PER_PAGE:-$DEFAULT_PER_PAGE}"
}

evlib_api_path() {
  local repo
  repo="$(evlib_repo)"
  if [ -n "${GITHUB_APP_EVENTS_API_PATH:-}" ]; then
    echo "${GITHUB_APP_EVENTS_API_PATH}"
  elif [ -n "$repo" ]; then
    echo "/repos/${repo}/events"
  else
    echo ""
  fi
}

# ---- Token refresh --------------------------------------------------------

_evlib_last_token_err=""

evlib_ensure_token() {
  local before after
  before="$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null || true)"
  if [ -x "$SCRIPT_DIR/token-check.sh" ]; then
    local err
    err="$("$SCRIPT_DIR/token-check.sh" --sync --quiet 2>&1)" || {
      if [ "$err" != "$_evlib_last_token_err" ]; then
        echo "[${PLUGIN_NAME}] token-check failed: ${err:-non-zero exit}" >&2
        _evlib_last_token_err="$err"
      fi
    }
  fi
  after="$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null || true)"
  if [ -n "$after" ] && [ "$after" != "$before" ]; then
    local slug
    slug="$(jq -r '.app_slug // empty' "$META_FILE" 2>/dev/null || true)"
    echo "[${PLUGIN_NAME}] token refreshed${slug:+ as ${slug}[bot]} (expires ${after})" >&2
    _evlib_last_token_err=""
  fi
  [ -s "$TOKEN_FILE" ]  # success only if a non-empty token exists
}

# ---- Event fetch ----------------------------------------------------------
# Sets global EVLIB_RESP to the raw JSON array (or "" on failure).
# Emits errors to stderr (deduplicated via _evlib_last_fetch_err).
# Returns 0 on success (valid JSON array), 1 on failure.

_evlib_last_fetch_err=""
EVLIB_RESP=""

evlib_fetch_events() {
  local api_path per_page token
  api_path="${1:-$(evlib_api_path)}"
  per_page="${2:-$(evlib_per_page)}"
  api_path="/${api_path#/}"  # normalize leading slash

  token="$(cat "$TOKEN_FILE" 2>/dev/null)"
  EVLIB_RESP="$(curl -s -m 15 \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com${api_path}?per_page=${per_page}" 2>/dev/null || true)"

  if printf '%s' "$EVLIB_RESP" | jq -e 'type=="array"' >/dev/null 2>&1; then
    _evlib_last_fetch_err=""
    return 0
  fi
  local msg
  msg="$(printf '%s' "$EVLIB_RESP" | jq -r '.message // "empty/non-JSON response"' 2>/dev/null || echo "request failed")"
  if [ "$msg" != "$_evlib_last_fetch_err" ]; then
    echo "[${PLUGIN_NAME}] events fetch failed: $msg" >&2
    _evlib_last_fetch_err="$msg"
  fi
  EVLIB_RESP=""
  return 1
}

# ---- Cursor / state file management --------------------------------------
# State file JSON: {"last_seen_id": "...", "last_fetch_ts": 1234567890,
#                   "stop_start_ts": null, "stop_notice_sent": false}

evlib_read_state() {
  if [ -f "$EVENTS_STATE_FILE" ]; then
    cat "$EVENTS_STATE_FILE" 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

evlib_get_last_seen_id() {
  evlib_read_state | jq -r '.last_seen_id // empty' 2>/dev/null || true
}

evlib_get_last_fetch_ts() {
  evlib_read_state | jq -r '.last_fetch_ts // 0' 2>/dev/null || echo 0
}

evlib_get_stop_start_ts() {
  evlib_read_state | jq -r '.stop_start_ts // empty' 2>/dev/null || true
}

evlib_get_stop_notice_sent() {
  evlib_read_state | jq -r '.stop_notice_sent // false' 2>/dev/null || echo false
}

# Update last_seen_id and last_fetch_ts atomically (preserves other fields).
evlib_write_cursor() {
  local new_id="$1"
  local now
  now="$(date +%s)"
  local existing
  existing="$(evlib_read_state)"
  local tmp="${EVENTS_STATE_FILE}.tmp.$$"
  printf '%s' "$existing" \
    | jq --arg id "$new_id" --argjson ts "$now" \
        '.last_seen_id = $id | .last_fetch_ts = $ts' \
    > "$tmp" 2>/dev/null \
    && mv "$tmp" "$EVENTS_STATE_FILE" \
    || rm -f "$tmp"
}

# Update stop-polling state fields.
evlib_write_stop_state() {
  local stop_start_ts="${1:-null}"    # null or UNIX timestamp
  local stop_notice_sent="${2:-false}" # true or false
  local existing
  existing="$(evlib_read_state)"
  local tmp="${EVENTS_STATE_FILE}.tmp.$$"
  printf '%s' "$existing" \
    | jq --argjson ss "$stop_start_ts" --argjson ns "$stop_notice_sent" \
        '.stop_start_ts = $ss | .stop_notice_sent = $ns' \
    > "$tmp" 2>/dev/null \
    && mv "$tmp" "$EVENTS_STATE_FILE" \
    || rm -f "$tmp"
}

evlib_clear_stop_state() {
  evlib_write_stop_state "null" "false"
}

# ---- Event extraction ------------------------------------------------------
# Extracts events newer than last_seen_id from EVLIB_RESP (which is
# newest-first from the API). Returns them oldest-first as one JSON object
# per line. Sets EVLIB_NEW_EVENTS (newline-delimited formatted strings)
# and EVLIB_NEWEST_ID (the id of the newest event in the response, "" if empty).

EVLIB_NEW_EVENTS=""
EVLIB_NEWEST_ID=""

# evlib_extract_new_events <last_seen_id> <per_page>
# Uses EVLIB_RESP (already fetched). Populates EVLIB_NEW_EVENTS and EVLIB_NEWEST_ID.
evlib_extract_new_events() {
  local last_seen="${1:-}"
  EVLIB_NEWEST_ID="$(printf '%s' "$EVLIB_RESP" | jq -r '.[0].id // empty' 2>/dev/null || true)"
  [ -n "$EVLIB_NEWEST_ID" ] || { EVLIB_NEW_EVENTS=""; return 0; }

  if [ -z "$last_seen" ]; then
    # No cursor — return all events (oldest-first).
    EVLIB_NEW_EVENTS="$(printf '%s' "$EVLIB_RESP" | jq -r '
      reverse | .[]
      | "[\(.created_at)] \(.type) by \(.actor.login) on \(.repo.name) (id \(.id))"
    ' 2>/dev/null || true)"
  else
    # Cursor exists — return only events above the stop marker (oldest-first).
    EVLIB_NEW_EVENTS="$(printf '%s' "$EVLIB_RESP" | jq -r --arg ls "$last_seen" '
      (([.[].id] | index($ls)) // length) as $i
      | .[0:$i] | reverse | .[]
      | "[\(.created_at)] \(.type) by \(.actor.login) on \(.repo.name) (id \(.id))"
    ' 2>/dev/null || true)"
  fi
}

# ---- Event formatting -----------------------------------------------------

# evlib_format_message <new_events_text> [<header>]
# Builds a Claude-facing message with the required disclaimer on line 1.
evlib_format_claude_message() {
  local events_text="$1"
  local header="${2:-}"
  {
    echo "not every event may be related to your current working task"
    echo ""
    [ -n "$header" ] && echo "$header"
    printf '%s' "$events_text"
  }
}

# ---- Output routing -------------------------------------------------------
# evlib_deliver <events_text> <delivery_mode> [<header>]
#
# Writes to audit log (all modes except disabled).
# Outputs hook JSON to stdout according to the matrix:
#   disabled -> nothing
#   file     -> audit log only, no stdout
#   user     -> systemMessage=full, no additionalContext
#   both     -> systemMessage=full + additionalContext=full
#   summary  -> systemMessage="events received from github", additionalContext=full
#
# For async rewake (UserPromptSubmit / Stop): caller must exit 2 after this
# when events were delivered.
evlib_deliver() {
  local events_text="$1"
  local mode="$2"
  local header="${3:-}"

  if [ "$mode" = "disabled" ]; then
    return 0
  fi

  local claude_msg
  claude_msg="$(evlib_format_claude_message "$events_text" "$header")"

  # Audit log (all non-disabled modes).
  {
    echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) [${mode}] ==="
    printf '%s\n' "$claude_msg"
    echo ""
  } >> "$EVENTS_AUDIT_LOG" 2>/dev/null || true

  # No stdout needed for file mode.
  [ "$mode" = "file" ] && return 0

  # Build hook JSON output.
  case "$mode" in
    user)
      printf '%s' "$claude_msg" | jq -Rs \
        '{hookSpecificOutput: {systemMessage: .}}'
      ;;
    both)
      printf '%s' "$claude_msg" | jq -Rs \
        '{hookSpecificOutput: {systemMessage: ., additionalContext: .}}'
      ;;
    summary)
      printf '%s' "$claude_msg" | jq -Rs \
        '{hookSpecificOutput: {systemMessage: "events received from github", additionalContext: .}}'
      ;;
    *)
      # Unknown mode — treat as file (already written to audit log).
      echo "[${PLUGIN_NAME}] unknown eventsDelivery mode: ${mode}" >&2
      ;;
  esac
}

# ---- Humanized duration ---------------------------------------------------

evlib_humanize_seconds() {
  local s="$1"
  if [ "$s" -ge 3600 ]; then
    printf "%dh %dm" $((s/3600)) $(((s%3600)/60))
  elif [ "$s" -ge 60 ]; then
    printf "%dm %ds" $((s/60)) $((s%60))
  else
    printf "%ds" "$s"
  fi
}
