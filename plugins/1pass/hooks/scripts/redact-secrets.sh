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
# Manifest: written by op-exec-env.sh (SessionStart hook) at:
#   ${CLAUDE_PLUGIN_DATA}/secrets-manifest.txt  — one var name per line

set -euo pipefail

# mapfile and ${!var} (indirect expansion) require bash 4.0+.
# Stock macOS ships bash 3.2 — exit cleanly rather than erroring.
if (( BASH_VERSINFO[0] < 4 )); then
  echo '{}'
  exit 0
fi

input="$(cat)"

# Extract the text content from tool_result.
# Per the official PostToolUse schema, tool_result is an object
# {"type": "text", "text": "..."}, not a raw string. jq -r on an object
# emits its JSON encoding, which escapes backslashes and double-quotes —
# secrets containing those chars would be escaped and never matched by
# grep -F. Extract .text when it's an object; fall back to treating it as
# a string in case the schema changes or a string-typed result is received.
tool_result="$(printf '%s' "$input" | jq -r '
  .tool_result |
  if type == "string" then .
  elif type == "object" then (.text // "")
  else ""
  end
' 2>/dev/null || true)"

if [ -z "$tool_result" ]; then
  echo '{}'
  exit 0
fi

# Locate the secrets manifest.
# CLAUDE_PLUGIN_DATA is set by the plugin runtime when this hook fires.
# The fallback mirrors the deterministic path Claude Code uses so the hook
# remains functional if the var is ever unset:
#   ${HOME}/.claude/plugins/data/{plugin-name}-{marketplace-name}
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/1pass-ai-mktpl}"
MANIFEST="${PLUGIN_DATA}/secrets-manifest.txt"

if [ ! -f "$MANIFEST" ]; then
  echo '{}'
  exit 0
fi

# Read var names (skip blank lines)
mapfile -t var_names < <(grep -v '^[[:space:]]*$' "$MANIFEST" 2>/dev/null || true)

if [ "${#var_names[@]}" -eq 0 ]; then
  echo '{}'
  exit 0
fi

# Build list of (name, value) pairs for vars that are:
#   - non-empty in the current environment
#   - at least 8 chars (avoid false positives on short common strings)
#   - single-line (multi-line PEM keys are skipped — they appear in raw
#     output only in unusual diagnostic contexts, and bash string
#     substitution handles newlines but grep -F match is line-oriented)
declare -a redact_names=()
declare -a redact_values=()

for var_name in "${var_names[@]}"; do
  [ -z "$var_name" ] && continue
  # Indirect env lookup — works on bash 4+
  value="${!var_name:-}"
  if [ -z "$value" ] || [ "${#value}" -lt 8 ]; then
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
  echo '{}'
  exit 0
fi

# Check which values appear in the tool result and replace them
found_names=()
redacted_result="$tool_result"

for i in "${!redact_names[@]}"; do
  var_name="${redact_names[$i]}"
  value="${redact_values[$i]}"

  if printf '%s' "$tool_result" | grep -qF -- "$value" 2>/dev/null; then
    # Bash parameter expansion for global literal string replacement.
    # The // prefix means "replace all occurrences"; the value is treated as a
    # literal string (not a pattern), so no escaping needed.
    redacted_result="${redacted_result//"${value}"/"****REDACTED(${var_name})****"}"
    found_names+=("$var_name")
  fi
done

if [ "${#found_names[@]}" -eq 0 ]; then
  echo '{}'
  exit 0
fi

# Format the list of redacted names
names_csv="$(IFS=', '; echo "${found_names[*]}")"

message="⚠️  SECRET VALUES DETECTED IN TOOL OUTPUT

The tool output above contained 1Password-managed secrets. The values must
not be repeated in responses, tool arguments, or logs.

Secrets detected: ${names_csv}

Why redacted: These values come from 1Password vaults via the 1pass plugin
ENVIRONMENT mapping. Exposing them in conversation transcripts or responses
creates a security risk.

Redacted form (prefer this when referencing the output):
---
${redacted_result}
---

SAFE PATTERNS — reference secrets without printing their values:
  ✅ Existence check: [[ -n \"\${VAR:-}\" ]] && echo \"set (\${#VAR} chars)\" || echo \"not set\"
  ✅ Auth effects:    op whoami | gh auth status | curl -s -o /dev/null -w \"%{http_code}\" <api>
  ✅ Inject via run:  op run --env-file .env.op -- your-command
  ✅ Plugin config:   1pass opExec.items handles injection at session start
  ❌ Never:           echo \"\$SECRET\" | env | grep NAME= | cat .env files | pgrep -af | ps aux"

jq -n --arg msg "$message" '{systemMessage: $msg}'
