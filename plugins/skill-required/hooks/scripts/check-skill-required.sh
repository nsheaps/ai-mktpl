#!/usr/bin/env bash
# check-skill-required.sh — PreToolUse hook for skill-required enforcement
# Checks if the required skill was recently loaded before allowing tool use.
#
# Config: ~/.claude/settings.skill-required.yaml (user-level)
#         ${CLAUDE_PROJECT_DIR}/.claude/settings.skill-required.yaml (project-level)
#
# Config format:
#   skill-required:
#     enabled: true
#     skills:
#       - name: "git-spice"
#         required_before:
#           - "Bash"
#         command_pattern:
#           - "gs "
#           - "git-spice"
#         max_tool_uses_before_reset: 10
#       - name: "scm-utils:commit"
#         required_before:
#           - "Bash"
#         command_pattern:
#           - "git commit"
#           - "git push"
#         max_tool_uses_before_reset: 5
set -euo pipefail

# Resolve plugin root (injected by claude-code as CLAUDE_PLUGIN_ROOT)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${_SCRIPT_DIR}/../.." && pwd)}"

# shellcheck source=../../lib/utils.sh
source "${_PLUGIN_ROOT}/lib/utils.sh"

# Read input and extract hook event name for reusable output
input="$(cat)"
HOOK_EVENT=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
HOOK_EVENT="${HOOK_EVENT:-PreToolUse}"

# Helper functions for PreToolUse hook output
allow() {
  jq -n --arg evt "$HOOK_EVENT" '{"hookSpecificOutput":{"hookEventName":$evt,"permissionDecision":"allow"}}'
  exit 0
}

deny() {
  local reason="$1"
  jq -n --arg evt "$HOOK_EVENT" --arg reason "$reason" '{"hookSpecificOutput":{"hookEventName":$evt,"permissionDecision":"deny","permissionDecisionReason":$reason}}'
  exit 0
}

# Check env var override
if [ "${CLAUDE_PLUGIN_SKILL_REQUIRED_ENABLED:-}" = "false" ]; then
  allow
fi

tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"

# Skip if no tool name or if it's the Skill tool itself (avoid circular blocking)
if [ -z "$tool_name" ] || [ "$tool_name" = "Skill" ]; then
  allow
fi

# Load config — project-level overrides user-level
project_config="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.skill-required.yaml"
user_config="$HOME/.claude/settings.skill-required.yaml"

config_file=""
if [ -f "$project_config" ]; then
  config_file="$project_config"
elif [ -f "$user_config" ]; then
  config_file="$user_config"
else
  # No config — nothing to enforce
  allow
fi

# Check if yq is available for YAML parsing
if ! command -v yq &>/dev/null; then
  # Can't parse config without yq — allow and continue
  allow
fi

# Check if enabled (go-yq: use 'select' or direct access, not '// default')
enabled="$(yq -r '.skill-required.enabled' "$config_file" 2>/dev/null || echo "true")"
if [ "$enabled" = "false" ]; then
  allow
fi

# Get skill rules count
skill_count="$(yq -r '.skill-required.skills | length' "$config_file" 2>/dev/null || echo "0")"
if [ "$skill_count" = "0" ]; then
  allow
fi

# Determine project slug for cache lookup
project_slug="$(get_project_slug)"
cache_dir="$HOME/.claude/cache/plugins/skill-required/${project_slug}"

# Extract all skill rule fields in a single yq call (reduces subprocess overhead)
# Output: JSON array of objects with name, required_before (array), command_pattern (array), max_uses
rules_json="$(yq -o=json '.skill-required.skills' "$config_file" 2>/dev/null || echo "[]")"

# Check each skill rule
for i in $(seq 0 $(( skill_count - 1 ))); do
  # Batch-read all fields for this rule in one jq call
  rule_json="$(echo "$rules_json" | jq -c ".[$i]")"

  skill_name="$(echo "$rule_json" | jq -r '.name // empty')"
  max_uses="$(echo "$rule_json" | jq -r '.max_tool_uses_before_reset // 10')"

  # Validate max_uses is a number
  if [ -z "$max_uses" ] || [ "$max_uses" = "null" ]; then
    max_uses=10
  fi

  if [ -z "$skill_name" ] || [ "$skill_name" = "null" ]; then
    continue
  fi

  # Check required_before — supports both YAML array and legacy pipe-separated string
  # Build a newline-separated list of tool names
  required_before_json="$(echo "$rule_json" | jq -c '.required_before // empty')"
  if [ -z "$required_before_json" ] || [ "$required_before_json" = "null" ]; then
    continue
  fi

  # Determine if value is a JSON array or a plain string
  tool_matches=false
  if echo "$required_before_json" | jq -e 'type == "array"' &>/dev/null; then
    # YAML array: ["Bash", "Edit"]
    while IFS= read -r t; do
      if [ "$t" = "$tool_name" ]; then
        tool_matches=true
        break
      fi
    done < <(echo "$required_before_json" | jq -r '.[]')
  else
    # Legacy pipe-separated string: "Bash|Edit"
    legacy_str="$(echo "$required_before_json" | jq -r '.')"
    IFS='|' read -ra tool_list <<< "$legacy_str"
    for t in "${tool_list[@]}"; do
      t="$(echo "$t" | xargs)"  # trim whitespace
      if [ "$t" = "$tool_name" ]; then
        tool_matches=true
        break
      fi
    done
  fi

  if [ "$tool_matches" != "true" ]; then
    continue
  fi

  # If there's a command_pattern, check it (only for Bash tool)
  command_pattern_json="$(echo "$rule_json" | jq -c '.command_pattern // empty')"
  if [ -n "$command_pattern_json" ] && [ "$command_pattern_json" != "null" ] && [ "$tool_name" = "Bash" ]; then
    command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    if [ -n "$command" ]; then
      pattern_matches=false
      if echo "$command_pattern_json" | jq -e 'type == "array"' &>/dev/null; then
        # YAML array: ["git commit", "git push"]
        while IFS= read -r p; do
          if echo "$command" | grep -qE "$p"; then
            pattern_matches=true
            break
          fi
        done < <(echo "$command_pattern_json" | jq -r '.[]')
      else
        # Legacy pipe-separated string: "git commit|git push"
        legacy_pat="$(echo "$command_pattern_json" | jq -r '.')"
        IFS='|' read -ra patterns <<< "$legacy_pat"
        for p in "${patterns[@]}"; do
          p="$(echo "$p" | xargs)"
          if echo "$command" | grep -qE "$p"; then
            pattern_matches=true
            break
          fi
        done
      fi
      if [ "$pattern_matches" != "true" ]; then
        continue
      fi
    fi
  fi

  # This rule applies — check if skill was recently read
  # Sanitize skill name for filesystem use (e.g. "scm-utils:commit" → "scm-utils--commit")
  safe_skill_name="$(sanitize_skill_name "$skill_name")"
  cache_file="${cache_dir}/${safe_skill_name}.json"

  if [ ! -f "$cache_file" ]; then
    deny "The '${skill_name}' skill must be loaded before using ${tool_name}. Run: Skill tool with skill=\"${skill_name}\""
  fi

  # Check tool uses since last skill read
  uses_since="$(jq -r '.tool_uses_since // 0' "$cache_file" 2>/dev/null || echo "0")"

  if [ "$uses_since" -ge "$max_uses" ]; then
    deny "The '${skill_name}' skill was loaded ${uses_since} tool uses ago (max: ${max_uses}). Please reload it: Skill tool with skill=\"${skill_name}\""
  fi

  # Increment the counter
  jq --argjson inc 1 '.tool_uses_since += $inc' "$cache_file" > "${cache_file}.tmp" && mv "${cache_file}.tmp" "$cache_file"
done

# All checks passed
allow
