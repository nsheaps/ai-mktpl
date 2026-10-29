#!/usr/bin/env bash
# cache-skill-read.sh — PostToolUse hook for Skill tool
# Records skill reads to a cache file for skill-required enforcement.
#
# Cache location: ~/.claude/cache/plugins/skill-required/<project-slug>/
# Cache format: JSON file per skill name with last_read timestamp and tool_uses_since counter
set -euo pipefail

# Resolve plugin root (injected by claude-code as CLAUDE_PLUGIN_ROOT)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${_SCRIPT_DIR}/../.." && pwd)}"

# shellcheck source=../../lib/utils.sh
source "${_PLUGIN_ROOT}/lib/utils.sh"

input="$(cat)"

# Extract the skill name from the tool input
# The Skill tool input has a "skill" field
skill_name="$(echo "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null || true)"

if [ -z "$skill_name" ]; then
  echo '{}'
  exit 0
fi

# Determine project slug for cache isolation
project_slug="$(get_project_slug)"

# Cache directory
cache_dir="$HOME/.claude/cache/plugins/skill-required/${project_slug}"
mkdir -p "$cache_dir"

# Sanitize skill name for filesystem use (e.g. "scm-utils:commit" → "scm-utils--commit")
safe_skill_name="$(sanitize_skill_name "$skill_name")"

# Write cache entry for this skill
cache_file="${cache_dir}/${safe_skill_name}.json"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg skill "$skill_name" \
  --arg ts "$timestamp" \
  '{
    skill: $skill,
    last_read: $ts,
    tool_uses_since: 0
  }' > "$cache_file"

echo '{}'
