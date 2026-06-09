#!/usr/bin/env bash
# events-monitor.sh — Poll the GitHub events REST API as the GitHub App and
# emit one line per NEW event.
#
# Keeps a cursor (the highest event id seen) so only events that arrive AFTER
# startup are reported — the first poll establishes a baseline without dumping
# the existing backlog. Refreshes the App token via token-check.sh before each
# poll, so it runs indefinitely past the 1h installation-token TTL.
#
# Usage:
#   events-monitor.sh --repo <owner/repo> [--interval <seconds>] [--once]
#                     [--api-path <path>] [--per-page <n>] [--cursor-file <path>]
#                     [--if-configured]
#
# This script is also wired as a plugin-native background monitor (see the
# plugin's experimental.monitors), which auto-starts it with --if-configured.
#
# Config precedence (highest first): CLI flag > env var > plugin setting > default
#   interval:  --interval | GITHUB_APP_EVENTS_INTERVAL | eventsPollIntervalSeconds | 15
#   repo:      --repo      | GITHUB_APP_EVENTS_REPO      | eventsRepo               | (required)
#   api-path:  --api-path  | GITHUB_APP_EVENTS_API_PATH  | (derived: /repos/<repo>/events)
#
# --api-path lets you watch other event feeds, e.g. /orgs/<org>/events,
#   /users/<user>/events, /networks/<owner>/<repo>/events, or /events.
# --if-configured exits 0 quietly (instead of erroring) when no repo is set, so
#   it is safe to auto-start as an always-on plugin monitor.
#
# Output split (so a plugin monitor only notifies on things you care about):
#   stdout (each line = one Monitor notification):
#     - one line per NEW event: [<created_at>] <EventType> by <actor> on <repo> (id <id>)
#     - [error] lines (auth/rate-limit/token-refresh failures), de-duplicated
#   stderr (operational log, not notifications): [start], [baseline], [token]
#
# Token source: same contract as the rest of the plugin — token-check.sh reads
#   GITHUB_APP_ID / GITHUB_INSTALLATION_ID / GITHUB_APP_PRIVATE_KEY from the env
#   (injected by the 1pass plugin) and maintains ${GITHUB_TOKEN_FILE}. If those
#   are absent but a valid token file already exists, the monitor uses it until
#   it expires.
set -uo pipefail

_self="${BASH_SOURCE[0]}"
while [ -L "$_self" ]; do _self="$(readlink -f "$_self")"; done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
PLUGIN_NAME="github-app"

# CLAUDE_PLUGIN_DATA fallback for running outside a hook context.
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/github-app-ai-mktpl}"
TOKEN_FILE="${GITHUB_TOKEN_FILE:-${CLAUDE_PLUGIN_DATA}/github-token}"
META_FILE="${TOKEN_FILE}.meta"

DEFAULT_INTERVAL=15
DEFAULT_PER_PAGE=50

# --- Best-effort plugin settings (no hard dependency on shared-lib) ----------
# If the shared-lib config reader is present, use it for defaults; otherwise
# fall back to env vars / CLI flags. Wrapped so a missing/broken lib never
# breaks the monitor.
setting_interval=""
setting_repo=""
_load_plugin_settings() {
  local sld
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    sld="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
  else
    sld="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
  fi
  [ -f "$sld/plugin-config-read.sh" ] || return 1
  # shellcheck source=/dev/null
  source "$sld/plugin-config-read.sh" 2>/dev/null || return 1
  setting_interval="$(plugin_get_config "eventsPollIntervalSeconds" "" 2>/dev/null || true)"
  setting_repo="$(plugin_get_config "eventsRepo" "" 2>/dev/null || true)"
  return 0
}
_load_plugin_settings || true

# --- Arg parsing -------------------------------------------------------------
cli_interval=""
cli_repo=""
cli_api_path=""
cli_per_page=""
cli_cursor_file=""
run_once=false
if_configured=false   # when set, no-op (exit 0) instead of erroring if no repo is configured

usage() {
  sed -n '2,30p' "$_self" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)        cli_repo="${2:-}"; shift 2 ;;
    --interval)    cli_interval="${2:-}"; shift 2 ;;
    --api-path)    cli_api_path="${2:-}"; shift 2 ;;
    --per-page)    cli_per_page="${2:-}"; shift 2 ;;
    --cursor-file) cli_cursor_file="${2:-}"; shift 2 ;;
    --once)          run_once=true; shift ;;
    --if-configured) if_configured=true; shift ;;
    -h|--help)       usage 0 ;;
    *) echo "github-app events-monitor: unknown arg: $1" >&2; usage 1 ;;
  esac
done

# --- Resolve config (CLI > env > setting > default) --------------------------
INTERVAL="${cli_interval:-${GITHUB_APP_EVENTS_INTERVAL:-${setting_interval:-$DEFAULT_INTERVAL}}}"
REPO="${cli_repo:-${GITHUB_APP_EVENTS_REPO:-${setting_repo:-}}}"
PER_PAGE="${cli_per_page:-${GITHUB_APP_EVENTS_PER_PAGE:-$DEFAULT_PER_PAGE}}"

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [ "$INTERVAL" -lt 1 ]; then
  echo "github-app events-monitor: invalid --interval '$INTERVAL' (must be a positive integer)" >&2
  exit 1
fi

# API path: explicit override, else derive from repo.
if [ -n "$cli_api_path" ] || [ -n "${GITHUB_APP_EVENTS_API_PATH:-}" ]; then
  API_PATH="${cli_api_path:-$GITHUB_APP_EVENTS_API_PATH}"
  LABEL="${REPO:-$API_PATH}"
else
  if [ -z "$REPO" ]; then
    # No repo/api-path configured. When auto-started as a plugin monitor
    # (--if-configured), this is the normal "not set up" state — exit quietly
    # so the monitor simply doesn't watch anything until eventsRepo is set.
    if [ "$if_configured" = true ]; then
      echo "github-app events-monitor: no repo configured (set github-app eventsRepo, GITHUB_APP_EVENTS_REPO, or pass --repo); not watching." >&2
      exit 0
    fi
    echo "github-app events-monitor: --repo <owner/repo> is required (or set GITHUB_APP_EVENTS_REPO / eventsRepo, or pass --api-path)" >&2
    usage 1
  fi
  API_PATH="/repos/${REPO}/events"
  LABEL="$REPO"
fi
API_PATH="/${API_PATH#/}"  # normalize leading slash

CURSOR_FILE="${cli_cursor_file:-${GITHUB_APP_EVENTS_CURSOR_FILE:-${CLAUDE_PLUGIN_DATA}/events-cursor$(echo "$API_PATH" | tr '/' '-')}}"
mkdir -p "$(dirname "$CURSOR_FILE")" "$CLAUDE_PLUGIN_DATA" 2>/dev/null || true

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- Token refresh (delegates to the plugin's own token-check.sh) ------------
last_token_err=""
ensure_token() {
  # Snapshot expiry before refresh so we can report when token-check actually
  # rotated the token (it runs --quiet, so it won't announce the refresh itself).
  local before after
  before="$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null || true)"
  if [ -x "$SCRIPT_DIR/token-check.sh" ]; then
    local err
    err="$("$SCRIPT_DIR/token-check.sh" --sync --quiet 2>&1)" || {
      # token-check failed; the existing token file may still be valid.
      if [ "$err" != "$last_token_err" ]; then
        echo "[$(ts)] [error] token-check: ${err:-non-zero exit}"
        last_token_err="$err"
      fi
    }
  fi
  after="$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null || true)"
  if [ -n "$after" ] && [ "$after" != "$before" ]; then
    local slug
    slug="$(jq -r '.app_slug // empty' "$META_FILE" 2>/dev/null || true)"
    echo "[$(ts)] [token] refreshed${slug:+ as ${slug}[bot]} (expires ${after})" >&2
    last_token_err=""   # a successful refresh clears any prior error state
  fi
  [ -s "$TOKEN_FILE" ]   # success only if a non-empty token exists
}

# --- Event fetch -------------------------------------------------------------
# Sets the global RESP to the response body and returns 0 when it's a JSON array.
# On failure emits a de-duplicated [error] line and returns 1. MUST be called
# directly (not in a $(...) subshell) so the [error] line reaches stdout and the
# dedup state in last_fetch_err persists across polls.
last_fetch_err=""
RESP=""
fetch_events() {
  local token
  token="$(cat "$TOKEN_FILE" 2>/dev/null)"
  RESP="$(curl -s -m 15 \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com${API_PATH}?per_page=${PER_PAGE}" 2>/dev/null || true)"
  if printf '%s' "$RESP" | jq -e 'type=="array"' >/dev/null 2>&1; then
    last_fetch_err=""
    return 0
  fi
  local msg
  msg="$(printf '%s' "$RESP" | jq -r '.message // "empty/non-JSON response"' 2>/dev/null || echo "request failed")"
  if [ "$msg" != "$last_fetch_err" ]; then
    echo "[$(ts)] [error] events fetch failed: $msg"
    last_fetch_err="$msg"
  fi
  return 1
}

# --- Cursor init -------------------------------------------------------------
# The cursor is the id of the newest event seen on the previous poll. GitHub
# event ids are NOT monotonic across event types (e.g. PullRequestReviewEvent
# ids sit in a lower range than PushEvent ids), so we must NOT treat "id > X"
# as "newer". Instead we rely on the API's reverse-chronological ordering and
# use the stored id purely as a stop marker: emit everything above it in the
# returned page, then remember the new top id.
last_seen=""
baseline_needed=1
if [ -s "$CURSOR_FILE" ]; then
  last_seen="$(cat "$CURSOR_FILE" 2>/dev/null || true)"
  [ -n "$last_seen" ] && baseline_needed=0
fi

echo "[$(ts)] [start] watching ${LABEL} (${API_PATH}) every ${INTERVAL}s (cursor=${last_seen:-<none>})" >&2

poll() {
  ensure_token || return 0   # error already emitted; try again next tick
  fetch_events || return 0   # sets RESP; error already emitted on failure

  local newest
  newest="$(printf '%s' "$RESP" | jq -r '.[0].id // empty' 2>/dev/null)"
  [ -z "$newest" ] && return 0   # empty feed

  if [ "$baseline_needed" -eq 1 ]; then
    last_seen="$newest"
    printf '%s' "$last_seen" > "$CURSOR_FILE"
    baseline_needed=0
    local cnt
    cnt="$(printf '%s' "$RESP" | jq -r 'length' 2>/dev/null || echo 0)"
    echo "[$(ts)] [baseline] ${cnt} recent events present; newest id ${last_seen} — reporting new events from here" >&2
    return 0
  fi

  # Take the items above the last-seen id (API order = newest-first), then emit
  # them oldest-first. If last_seen isn't on the page (more than per_page new
  # events, or it aged off), index is null and we emit the whole page.
  local new
  new="$(printf '%s' "$RESP" | jq -r --arg ls "$last_seen" '
    (([.[].id] | index($ls)) // length) as $i
    | .[0:$i] | reverse | .[]
    | "[\(.created_at)] \(.type) by \(.actor.login) on \(.repo.name) (id \(.id))"' 2>/dev/null)"

  if [ -n "$new" ]; then
    printf '%s\n' "$new"
    last_seen="$newest"
    printf '%s' "$last_seen" > "$CURSOR_FILE"
  fi
}

if [ "$run_once" = true ]; then
  poll
  exit 0
fi

while true; do
  poll
  sleep "$INTERVAL"
done
