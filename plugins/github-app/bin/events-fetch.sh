#!/usr/bin/env bash
# events-fetch.sh — One-shot GitHub events fetcher for hook-driven delivery.
#
# Used by the plugin's hooks/hooks.json to deliver GitHub events to Claude
# and/or the user at specific session lifecycle points.
#
# Usage:
#   events-fetch.sh --event <event-type>
#
# Event types:
#   session-start-startup  Show last 10 events; set cursor baseline.
#   session-start-resume   Show events since last fetch.
#   user-prompt-submit     Show events since last fetch (async + rewake).
#   stop                   Poll until events arrive or timeout (async + rewake).
#
# Output routing is controlled by eventsDelivery config (see plugin settings):
#   disabled  -- exit 0 immediately, no fetch, no output
#   file      -- append to audit log only, no hook JSON output
#   user      -- systemMessage to user (full text), no additionalContext
#   both      -- systemMessage + additionalContext (both full text)
#   summary   -- systemMessage="events received from github", additionalContext=full
#
# Exit codes (used by async rewake hooks):
#   0 -- no events to deliver (or delivery mode is file/disabled)
#   2 -- events delivered (triggers asyncRewake when hook is configured with asyncRewake: true)
#
# Config precedence (highest first): env var > plugin setting > default
#   eventsDelivery      GITHUB_APP_EVENTS_DELIVERY   disabled
#   eventsRepo          GITHUB_APP_EVENTS_REPO        (required)
#   eventsPollInterval  GITHUB_APP_EVENTS_INTERVAL    15
#   eventsStopTimeout   GITHUB_APP_EVENTS_STOP_TIMEOUT 600
#   eventsStopNotice    GITHUB_APP_EVENTS_STOP_NOTICE  480
set -uo pipefail

_self="${BASH_SOURCE[0]}"
while [ -L "$_self" ]; do _self="$(readlink -f "$_self")"; done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
PLUGIN_NAME="github-app"

# CLAUDE_PLUGIN_DATA fallback for running outside a hook context.
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/github-app-ai-mktpl}"

# Source shared library.
# shellcheck source=./events-lib.sh
source "${SCRIPT_DIR}/events-lib.sh"

# ---- Arg parsing ----------------------------------------------------------

EVENT_TYPE=""

usage() {
  sed -n '2,35p' "$_self" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --event) EVENT_TYPE="${2:-}"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "github-app events-fetch: unknown arg: $1" >&2; usage 1 ;;
  esac
done

if [ -z "$EVENT_TYPE" ]; then
  echo "github-app events-fetch: --event is required" >&2
  usage 1
fi

case "$EVENT_TYPE" in
  session-start-startup|session-start-resume|user-prompt-submit|stop) ;;
  *)
    echo "github-app events-fetch: unknown --event value: $EVENT_TYPE" >&2
    echo "  valid values: session-start-startup, session-start-resume, user-prompt-submit, stop" >&2
    exit 1 ;;
esac

# ---- Check delivery mode --------------------------------------------------

DELIVERY="$(evlib_delivery)"
REPO="$(evlib_repo)"
API_PATH="$(evlib_api_path)"

# disabled: exit immediately, no fetch, no output.
if [ "$DELIVERY" = "disabled" ]; then
  exit 0
fi

# No repo configured — exit quietly (same as disabled).
if [ -z "$API_PATH" ]; then
  exit 0
fi

# ---- Helpers --------------------------------------------------------------

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_deliver_and_maybe_exit2() {
  local events_text="$1"
  local header="${2:-}"
  evlib_deliver "$events_text" "$DELIVERY" "$header"
  # For async rewake hooks (user-prompt-submit, stop): exit 2 to trigger rewake.
  # For session-start: exit 0 (synchronous hook, additionalContext accepted on 0).
  case "$EVENT_TYPE" in
    user-prompt-submit|stop)
      exit 2 ;;
    *)
      exit 0 ;;
  esac
}

# ---- session-start-startup ------------------------------------------------
# Fetch the last 10 events, show them to establish context, then set cursor.

_do_session_start_startup() {
  evlib_ensure_token || exit 0  # No token — skip silently.
  evlib_fetch_events "$API_PATH" 10 || exit 0

  local newest_id
  newest_id="$(printf '%s' "$EVLIB_RESP" | jq -r '.[0].id // empty' 2>/dev/null || true)"
  [ -n "$newest_id" ] || exit 0  # Empty feed.

  # Format all 10 (oldest-first).
  local events_text
  events_text="$(printf '%s' "$EVLIB_RESP" | jq -r '
    reverse | .[]
    | "[\(.created_at)] \(.type) by \(.actor.login) on \(.repo.name) (id \(.id))"
  ' 2>/dev/null || true)"

  [ -n "$events_text" ] || exit 0

  # Advance cursor to newest seen.
  evlib_write_cursor "$newest_id"

  local header="Recent GitHub events for ${REPO:-$API_PATH} (last 10):"
  evlib_deliver "$events_text" "$DELIVERY" "$header"
  exit 0
}

# ---- session-start-resume / user-prompt-submit ----------------------------
# Fetch events since last cursor. Advance cursor. Deliver if any.

_do_since_last_fetch() {
  evlib_ensure_token || exit 0
  evlib_fetch_events "$API_PATH" "$(evlib_per_page)" || exit 0

  local last_seen
  last_seen="$(evlib_get_last_seen_id)"

  evlib_extract_new_events "$last_seen"

  [ -n "$EVLIB_NEWEST_ID" ] || exit 0  # Empty feed.

  if [ -n "$EVLIB_NEW_EVENTS" ]; then
    # Advance cursor.
    evlib_write_cursor "$EVLIB_NEWEST_ID"
    local count
    count="$(printf '%s\n' "$EVLIB_NEW_EVENTS" | wc -l | tr -d ' ')"
    local header="${count} new GitHub event(s) for ${REPO:-$API_PATH}:"
    _deliver_and_maybe_exit2 "$EVLIB_NEW_EVENTS" "$header"
  fi

  # No new events: update the fetch timestamp (cursor id unchanged).
  evlib_write_cursor "${last_seen:-$EVLIB_NEWEST_ID}"
  exit 0
}

# ---- stop -----------------------------------------------------------------
# Poll until events arrive or timeout. Re-wake Claude on events (exit 2).
# Emit "no events received" notice at eventsStopNoticeSeconds.
# Allow stop at eventsStopTimeoutSeconds (exit 0).

_do_stop() {
  local stop_timeout
  stop_timeout="$(evlib_stop_timeout)"
  local stop_notice
  stop_notice="$(evlib_stop_notice)"
  local interval
  interval="$(evlib_interval)"

  # Read or initialize stop sequence state.
  local stop_start_ts
  stop_start_ts="$(evlib_get_stop_start_ts)"
  local stop_notice_sent
  stop_notice_sent="$(evlib_get_stop_notice_sent)"
  local now
  now="$(date +%s)"

  if [ -z "$stop_start_ts" ]; then
    stop_start_ts="$now"
    evlib_write_stop_state "$stop_start_ts" "false"
    stop_notice_sent="false"
  fi

  evlib_ensure_token || { evlib_clear_stop_state; exit 0; }

  local last_seen
  last_seen="$(evlib_get_last_seen_id)"

  # Polling loop: runs asynchronously in background (hook has async: true).
  while true; do
    sleep "$interval"
    now="$(date +%s)"
    local elapsed=$(( now - stop_start_ts ))

    # Hard timeout: allow the stop.
    if [ "$elapsed" -ge "$stop_timeout" ]; then
      evlib_clear_stop_state
      exit 0
    fi

    # Fetch events.
    if evlib_fetch_events "$API_PATH" "$(evlib_per_page)"; then
      local current_last_seen
      current_last_seen="$(evlib_get_last_seen_id)"
      evlib_extract_new_events "$current_last_seen"

      if [ -n "$EVLIB_NEW_EVENTS" ]; then
        # New events arrived — deliver and re-wake Claude.
        evlib_write_cursor "$EVLIB_NEWEST_ID"
        evlib_clear_stop_state
        local count
        count="$(printf '%s\n' "$EVLIB_NEW_EVENTS" | wc -l | tr -d ' ')"
        local header="${count} new GitHub event(s) for ${REPO:-$API_PATH} (received while session was stopping):"
        evlib_deliver "$EVLIB_NEW_EVENTS" "$DELIVERY" "$header"
        # Re-wake Claude (Stop hook with asyncRewake: true). Only re-wake for
        # modes that push content to Claude; file mode doesn't re-wake.
        case "$DELIVERY" in
          user|both|summary) exit 2 ;;
          *) evlib_clear_stop_state; exit 0 ;;
        esac
      fi
    fi

    # At notice threshold with still no events: emit once, then allow stop.
    if [ "$stop_notice_sent" = "false" ] && [ "$elapsed" -ge "$stop_notice" ]; then
      stop_notice_sent="true"
      evlib_write_stop_state "$stop_start_ts" "true"

      local last_fetch_ts
      last_fetch_ts="$(evlib_get_last_fetch_ts)"
      local since_last=$(( now - last_fetch_ts ))
      local human_since
      human_since="$(evlib_humanize_seconds "$since_last")"

      local notice_text="no github events received in the last ${human_since}"
      evlib_deliver "$notice_text" "$DELIVERY" ""
      # Re-wake Claude with the notice, then allow stop.
      case "$DELIVERY" in
        user|both|summary) exit 2 ;;
        *)
          # file mode: wrote to audit log, allow stop.
          evlib_clear_stop_state; exit 0 ;;
      esac
    fi
  done
}

# ---- Dispatch -------------------------------------------------------------

case "$EVENT_TYPE" in
  session-start-startup)
    _do_session_start_startup ;;
  session-start-resume)
    _do_since_last_fetch ;;
  user-prompt-submit)
    _do_since_last_fetch ;;
  stop)
    _do_stop ;;
esac
