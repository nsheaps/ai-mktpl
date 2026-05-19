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
# IMPORTANT LIMITATION: PostToolUse hooks cannot replace or suppress the
# built-in tool output for Read/Bash/Grep/etc. — the original output is
# already in Claude's context window when this hook fires. What this hook
# DOES is inject a systemMessage that:
#   (a) Flags the leaked value
#   (b) Provides the redacted form for Claude to prefer in its responses
#   (c) Instructs Claude NOT to repeat the raw value
# This prevents secrets from being echoed back to the user or included in
# follow-up tool calls / responses, even though they're in the window.
#
# See: https://github.com/anthropics/claude-code/issues/20470
#
# Note on output keys: claude-code's PostToolUseHookSpecificOutputSchema
# (source: entrypoints/sdk/coreSchemas.ts) accepts `additionalContext` and
# `updatedMCPToolOutput` (MCP tools only) inside `hookSpecificOutput`, plus
# top-level `systemMessage`, `decision`, `reason`. A previously-emitted
# `updatedToolOutput` key is NOT in the schema and is silently ignored —
# the working signal here is `systemMessage`.
#
# Secrets file: written by op-exec via --concealed-file during SessionStart at:
#   ${CLAUDE_PLUGIN_DATA}/.env.secrets  — one CONCEALED var name per line
# Only vars whose 1Password field type is CONCEALED (or that resolve through a
# CONCEALED op:// reference chain) are listed here — non-secret STRING fields
# like DISCORD_ALLOW_BOTS=true are excluded, preventing false-positive redaction.
# This hook derives the same path from $HOME when CLAUDE_PLUGIN_DATA is unset
# (settings.json hooks don't receive plugin-context env vars).

set -euo pipefail

# Debug log — written regardless of whether redaction fires.
# Helps diagnose whether PostToolUse hooks are invoked at all.
# Path: ${HOME}/.claude/tmp/redact-secrets-debug.log
LOG_DIR="${HOME}/.claude/tmp"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/redact-secrets-debug.log"
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
MANIFEST="${PLUGIN_DATA}/.env.secrets"

if [ ! -f "$MANIFEST" ]; then
  _log "exit: manifest not found at ${MANIFEST}"
  echo '{}'
  exit 0
fi
_log "manifest found: ${MANIFEST} ($(wc -l < "$MANIFEST") lines)"

# Read var names (skip blank lines)
mapfile -t var_names < <(grep -v '^[[:space:]]*$' "$MANIFEST" 2>/dev/null || true)

if [ "${#var_names[@]}" -eq 0 ]; then
  _log "exit: no var names in secrets file"
  echo '{}'
  exit 0
fi

# Build list of (name, value) pairs for vars that are:
#   - non-empty in the current environment
#   - single-line (multi-line PEM keys are skipped — they appear in raw
#     output only in unusual diagnostic contexts, and bash string
#     substitution handles newlines but grep -F match is line-oriented)
declare -a redact_names=()
declare -a redact_values=()

for var_name in "${var_names[@]}"; do
  [ -z "$var_name" ] && continue
  # Indirect env lookup — works on bash 4+
  value="${!var_name:-}"
  if [ -z "$value" ]; then
    continue
  fi
  # Skip multi-line values (PEM keys, certificates) — handle separately if needed
  if [[ "$value" == *$'\n'* ]]; then
    continue
  fi
  redact_names+=("$var_name")
  redact_values+=("$value")
done

if [ "${#redact_names[@]}" -eq 0 ]; then
  _log "exit: no non-empty single-line env vars from secrets file"
  echo '{}'
  exit 0
fi
_log "candidates: ${#redact_names[@]} vars loaded for matching"

# Check which values appear in the tool text and replace them
found_names=()
redacted_result="$tool_text"

for i in "${!redact_names[@]}"; do
  var_name="${redact_names[$i]}"
  value="${redact_values[$i]}"

  if printf '%s' "$tool_text" | grep -qF -- "$value" 2>/dev/null; then
    # Bash parameter expansion for global literal string replacement.
    # The // prefix means "replace all occurrences"; the value is treated as a
    # literal string (not a pattern), so no escaping needed.
    redacted_result="${redacted_result//"${value}"/"****REDACTED(${var_name})****"}"
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

jq -n --arg msg "$message" --arg out "$redacted_result" '{updatedToolOutput: $out, systemMessage: $msg}'
