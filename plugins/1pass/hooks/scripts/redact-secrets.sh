#!/usr/bin/env bash
# redact-secrets.sh — PostToolUse hook for 1pass plugin
#
# Scans each tool output for secret values that were injected by the 1pass
# plugin (via op-exec ENVIRONMENT mapping). When a secret is found, injects
# a systemMessage with:
#   - The redacted version of the output (secrets replaced with
#     ****REDACTED(ENV_VAR_NAME)****)
#   - Why the value was redacted
#   - Safe patterns for referencing secrets without exposing their values
#
# When a secret is found, this hook emits:
#   { hookSpecificOutput: { hookEventName: "PostToolUse",
#                           updatedToolOutput: <redacted tool_response>,
#                           additionalContext: <warning message> } }
#
# updatedToolOutput (object) replaces what Claude sees in the tool result.
# additionalContext surfaces as a system-reminder instructing Claude not to
# repeat the raw value in future tool calls or responses.
#
# Note on output keys: claude-code's PostToolUseHookSpecificOutputSchema
# (source: entrypoints/sdk/coreSchemas.ts) accepts `additionalContext` and
# `updatedMCPToolOutput` (MCP tools only) inside `hookSpecificOutput`, plus
# top-level `systemMessage`, `decision`, `reason`. The `updatedToolOutput`
# key inside `hookSpecificOutput` replaces the tool result visible to Claude
# when passed as a JSON object (not a string) — use --argjson, not --arg.
#
# Secrets file: written by op-exec via --concealed-kv-file during SessionStart at:
#   ${CLAUDE_PLUGIN_DATA}/.env.secrets — one `NAME=value` pair per line, mode 600.
# Only fields with type == CONCEALED (or that resolve through a CONCEALED op://
# reference chain) are listed — non-secret STRING fields like DISCORD_ALLOW_BOTS
# are excluded, preventing false-positive redaction.
#
# As of plugin v0.6.0 the file carries VALUES, not just names: this decouples
# redaction from env propagation, which mattered for CLAUDE_CODE_OAUTH_TOKEN
# (claude-code holds it in its own process env but does NOT export it to
# PostToolUse hook subprocesses, apparent security boundary — so the old
# env-lookup path was always missing).
#
# This hook derives the same path from $HOME when CLAUDE_PLUGIN_DATA is unset
# (settings.json hooks don't receive plugin-context env vars).

set -euo pipefail

# Debug log — written regardless of whether redaction fires.
# Helps diagnose whether PostToolUse hooks are invoked at all.
# Path: per-agent plugin data dir (same fallback as PLUGIN_DATA below), so
# logs from alex/jack/henry don't interleave in a shared $HOME path.
LOG_FILE="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/1pass-ai-mktpl}/redact-secrets-debug.log"
mkdir -p "$(dirname "$LOG_FILE")"
_log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG_FILE"; }

_log "=== invoked (CLAUDE_PLUGIN_DATA=${CLAUDE_PLUGIN_DATA:-unset})"

# mapfile and ${!var} (indirect expansion) require bash 4.0+.
# Stock macOS ships bash 3.2 — exit cleanly rather than erroring.
if (( BASH_VERSINFO[0] < 4 )); then
  _log "exit: bash < 4 (${BASH_VERSION})"
  echo '{}'
  exit 0
fi

input="$(cat)"

# Extract the textual content of the tool response.
#
# Per claude-code source (entrypoints/sdk/coreSchemas.ts
# PostToolUseHookInputSchema), the field is `tool_response` (z.unknown), NOT
# `tool_result` as some external docs claim. Per-tool shapes observed at
# runtime (claude-code v2.1.x):
#
#   Bash:   { stdout, stderr, interrupted, isImage, noOutputExpected }
#   Read/Edit/Write/Grep/Glob: typically { type: "text", text: "..." } or a
#                              bare string — older docs reflect this shape.
#   MCP tools: tool-specific objects.
#
# We coalesce the candidate textual fields so secret scanning covers all of
# them. Non-textual responses (e.g. images) fall through to "" and the hook
# exits without redaction.
tool_text="$(printf '%s' "$input" | jq -r '
  .tool_response |
  if type == "string" then .
  elif type == "object" then
    [ (.stdout // ""), (.stderr // ""), (.text // ""), (.output // "") ]
    | map(select(. != "")) | join("\n")
  else ""
  end
' 2>/dev/null || true)"

# Capture the full tool_response as compact JSON for use in updatedToolOutput.
# Replacement in this string produces a JSON object we can pass via --argjson.
tool_response_json="$(printf '%s' "$input" | jq -c '.tool_response' 2>/dev/null || true)"

if [ -z "$tool_text" ]; then
  _log "exit: empty tool_response text"
  echo '{}'
  exit 0
fi

# Locate the secrets manifest.
# CLAUDE_PLUGIN_DATA is set when invoked as a plugin hook, but NOT when
# invoked from settings.json (the working registration path). The deterministic
# fallback mirrors how CLAUDE_PLUGIN_DATA is constructed by Claude Code:
#   ${HOME}/.claude/plugins/data/{plugin-name}-{marketplace-name}
# Since HOME is agent-specific (e.g., /home/nsheaps/.agents/jack), this
# correctly resolves to each agent's isolated plugin data directory.
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/1pass-ai-mktpl}"
# .env.secrets contains `NAME=value` pairs, one per line. Do NOT `source` this
# file — parse it directly. op-exec writes it via --concealed-kv-file at session
# start, mode 600.
SECRETS_FILE="${PLUGIN_DATA}/.env.secrets"

if [ ! -f "$SECRETS_FILE" ]; then
  _log "exit: secrets file not found at ${SECRETS_FILE}"
  echo '{}'
  exit 0
fi
_log "secrets file found: ${SECRETS_FILE} ($(wc -l < "$SECRETS_FILE") lines)"

# Parse `NAME=value` lines. Use ${line%%=*} / ${line#*=} so values that contain
# `=` are preserved intact (only the FIRST `=` separates name from value).
# Multi-line values cannot appear here — op-exec --concealed-kv-file skips them
# at write time (same constraint as the line-oriented redaction format).
declare -a redact_names=()
declare -a redact_values=()

while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  case "$line" in '#'*) continue ;; esac
  if [[ "$line" != *=* ]]; then
    continue
  fi
  var_name="${line%%=*}"
  value="${line#*=}"
  [ -z "$var_name" ] && continue
  [ -z "$value" ] && continue
  redact_names+=("$var_name")
  redact_values+=("$value")
done < "$SECRETS_FILE"

if [ "${#redact_names[@]}" -eq 0 ]; then
  _log "exit: no non-empty single-line env vars from secrets file"
  echo '{}'
  exit 0
fi
_log "candidates: ${#redact_names[@]} vars loaded for matching"

# Check which values appear in the tool text and replace them
found_names=()
redacted_result="$tool_text"
redacted_response_json="$tool_response_json"

for i in "${!redact_names[@]}"; do
  var_name="${redact_names[$i]}"
  value="${redact_values[$i]}"

  if printf '%s' "$tool_text" | grep -qF -- "$value" 2>/dev/null; then
    # Bash parameter expansion for global literal string replacement.
    # The // prefix means "replace all occurrences"; the value is treated as a
    # literal string (not a pattern), so no escaping needed.
    redacted_result="${redacted_result//"${value}"/"****REDACTED(${var_name})****"}"
    # Also replace in the full JSON string so updatedToolOutput carries the
    # redacted value as a proper JSON object (passed via --argjson below).
    redacted_response_json="${redacted_response_json//"${value}"/"****REDACTED(${var_name})****"}"
    found_names+=("$var_name")
  fi
done

if [ "${#found_names[@]}" -eq 0 ]; then
  _log "exit: no secret values matched in tool output"
  echo '{}'
  exit 0
fi
_log "REDACTED: ${found_names[*]}"

# Format the list of redacted names
names_csv="$(IFS=', '; echo "${found_names[*]}")"

message="⚠️ 1pass plugin redacted secret values in the tool output above.

Secrets detected: ${names_csv}

These values come from 1Password vaults (1pass plugin ENVIRONMENT mapping). Do NOT repeat raw values in responses, tool arguments, or logs. The redacted output has replaced the original above."

# updatedToolOutput must be a JSON object (not string) for Claude Code to
# accept it. Use --argjson so jq parses $redacted_response_json as JSON.
# If parsing fails (malformed JSON after substitution), fall back to
# systemMessage-only so the warning still surfaces.
if jq -e . >/dev/null 2>&1 <<<"$redacted_response_json"; then
  jq -cn --arg msg "$message" --argjson out "$redacted_response_json" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", updatedToolOutput: $out, additionalContext: $msg}}'
else
  _log "warn: redacted_response_json is not valid JSON, falling back to systemMessage"
  jq -cn --arg msg "$message" '{systemMessage: $msg}'
fi
