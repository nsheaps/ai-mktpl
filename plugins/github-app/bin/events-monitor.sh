#!/usr/bin/env bash
# events-monitor.sh — Poll the GitHub events REST API as the GitHub App and
# emit one line per NEW event. Intended as a manual/CLI watcher.
#
# The hook-driven delivery of GitHub events is handled by events-fetch.sh
# (sourced via hooks/hooks.json). This script remains as a standalone monitor
# for use via the Monitor tool, cron, or direct invocation.
#
# Usage:
#   events-monitor.sh --repo <owner/repo> [--interval <seconds>] [--once]
#                     [--api-path <path>] [--per-page <n>] [--cursor-file <path>]
#                     [--if-configured]
#
# Config precedence (highest first): CLI flag > env var > plugin setting > default
#   interval:  --interval | GITHUB_APP_EVENTS_INTERVAL | eventsPollIntervalSeconds | 15
#   repo:      --repo      | GITHUB_APP_EVENTS_REPO      | eventsRepo               | (required)
#   api-path:  --api-path  | GITHUB_APP_EVENTS_API_PATH  | (derived: /repos/<repo>/events)
#
# --api-path lets you watch other event feeds, e.g. /orgs/<org>/events,
#   /users/<user>/events, /networks/<owner>/<repo>/events, or /events.
# --if-configured exits 0 quietly (instead of erroring) when no repo is set, so
#   it is safe to call from scripts without a repo configured.
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

# Source shared events library.
# shellcheck source=./events-lib.sh
source "${SCRIPT_DIR}/events-lib.sh"

# --- Arg parsing -------------------------------------------------------------
cli_interval=""
cli_repo=""
cli_api_path=""
cli_per_page=""
cli_cursor_file=""
run_once=false
if_configured=false   # when set, no-op (exit 0) instead of erroring if no repo is configured

usage() {
  sed -n '2,40p' "$_self" | sed 's/^# \{0,1\}//'
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
INTERVAL="${cli_interval:-$(evlib_interval)}"
REPO="${cli_repo:-$(evlib_repo)}"
PER_PAGE="${cli_per_page:-$(evlib_per_page)}"

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [ "$INTERVAL" -lt 1 ]; then
  echo "github-app events-monitor: invalid --interval '$INTERVAL' (must be a positive integer)" >&2
  exit 1
fi

# API path: explicit override, else derive from repo.
if [ -n "${cli_api_path:-}" ] || [ -n "${GITHUB_APP_EVENTS_API_PATH:-}" ]; then
  API_PATH="${cli_api_path:-$GITHUB_APP_EVENTS_API_PATH}"
  LABEL="${REPO:-$API_PATH}"
else
  if [ -z "$REPO" ]; then
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

# Monitor uses its own cursor file (separate from the hook-state cursor),
# so it can run alongside the hook-driven delivery independently.
CURSOR_FILE="${cli_cursor_file:-${GITHUB_APP_EVENTS_CURSOR_FILE:-${CLAUDE_PLUGIN_DATA}/events-cursor$(echo "$API_PATH" | tr '/' '-')}}"
mkdir -p "$(dirname "$CURSOR_FILE")" "$CLAUDE_PLUGIN_DATA" 2>/dev/null || true

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- Cursor init -------------------------------------------------------------
last_seen=""
baseline_needed=1
if [ -s "$CURSOR_FILE" ]; then
  last_seen="$(cat "$CURSOR_FILE" 2>/dev/null || true)"
  [ -n "$last_seen" ] && baseline_needed=0
fi

echo "[$(ts)] [start] watching ${LABEL} (${API_PATH}) every ${INTERVAL}s (cursor=${last_seen:-<none>})" >&2

# --- Poll function -----------------------------------------------------------
# Uses evlib_ensure_token and evlib_fetch_events from events-lib.sh.
# Emits new events to stdout (one line per event).
last_fetch_err_mon=""
poll() {
  evlib_ensure_token || return 0  # error already emitted to stderr; try again next tick

  if ! evlib_fetch_events "$API_PATH" "$PER_PAGE"; then
    return 0  # error already emitted; try again next tick
  fi

  local newest
  newest="$(printf '%s' "$EVLIB_RESP" | jq -r '.[0].id // empty' 2>/dev/null)"
  [ -z "$newest" ] && return 0   # empty feed

  if [ "$baseline_needed" -eq 1 ]; then
    last_seen="$newest"
    printf '%s' "$last_seen" > "$CURSOR_FILE"
    baseline_needed=0
    local cnt
    cnt="$(printf '%s' "$EVLIB_RESP" | jq -r 'length' 2>/dev/null || echo 0)"
    echo "[$(ts)] [baseline] ${cnt} recent events present; newest id ${last_seen} — reporting new events from here" >&2
    return 0
  fi

  # Take the items above the last-seen id (API order = newest-first), then emit
  # them oldest-first.
  local new
  new="$(printf '%s' "$EVLIB_RESP" | jq -r --arg ls "$last_seen" '
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
