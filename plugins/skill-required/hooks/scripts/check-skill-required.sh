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
#         required_before: "Bash"
#         command_pattern: "gs |git-spice"
#         max_tool_uses_before_reset: 10
#       - name: "scm-utils:commit"
#         required_before: "Bash"
#         command_pattern: "git commit|git push"
#         max_tool_uses_before_reset: 5
set -euo pipefail

# Helper functions for PreToolUse hook output
allow() {
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
}

deny() {
  local reason="$1"
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":$(echo "$reason" | jq -Rs .)}}"
  exit 0
}

# Check env var override
if [ "${CLAUDE_PLUGIN_SKILL_REQUIRED_ENABLED:-}" = "false" ]; then
  allow
fi

input="$(cat)"

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

# Determine project slug
project_dir="${CLAUDE_PROJECT_DIR:-unknown}"
project_slug="$(echo "$project_dir" | sed 's|/|_|g' | sed 's|^_||')"
cache_dir="$HOME/.claude/cache/plugins/skill-required/${project_slug}"

# Check each skill rule
for i in $(seq 0 $(( skill_count - 1 ))); do
  skill_name="$(yq -r ".skill-required.skills[$i].name" "$config_file" 2>/dev/null || true)"
  required_before="$(yq -r ".skill-required.skills[$i].required_before" "$config_file" 2>/dev/null || true)"
  command_pattern="$(yq -r ".skill-required.skills[$i].command_pattern" "$config_file" 2>/dev/null || true)"
  max_uses="$(yq -r ".skill-required.skills[$i].max_tool_uses_before_reset" "$config_file" 2>/dev/null || echo "10")"
  # Default max_uses to 10 if null/empty
  if [ -z "$max_uses" ] || [ "$max_uses" = "null" ]; then
    max_uses=10
  fi

  # Check if this rule applies to the current tool
  if [ -z "$required_before" ] || [ "$required_before" = "null" ]; then
    continue
  fi

  # Check if tool name matches (pipe-separated list)
  tool_matches=false
  IFS='|' read -ra tool_list <<< "$required_before"
  for t in "${tool_list[@]}"; do
    t="$(echo "$t" | xargs)"  # trim whitespace
    if [ "$t" = "$tool_name" ]; then
      tool_matches=true
      break
    fi
  done

  if [ "$tool_matches" != "true" ]; then
    continue
  fi

  # If there's a command_pattern, check it (only for Bash tool)
  if [ -n "$command_pattern" ] && [ "$command_pattern" != "null" ] && [ "$tool_name" = "Bash" ]; then
    command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    if [ -n "$command" ]; then
      pattern_matches=false
      IFS='|' read -ra patterns <<< "$command_pattern"
      for p in "${patterns[@]}"; do
        p="$(echo "$p" | xargs)"
        if echo "$command" | grep -qE "$p"; then
          pattern_matches=true
          break
        fi
      done
      if [ "$pattern_matches" != "true" ]; then
        continue
      fi
    fi
  fi

  # This rule applies — check if skill was recently read
  cache_file="${cache_dir}/${skill_name}.json"

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
