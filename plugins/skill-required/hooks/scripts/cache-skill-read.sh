#!/usr/bin/env bash
# cache-skill-read.sh — PostToolUse hook for Skill tool
# Records skill reads to a cache file for skill-required enforcement.
#
# Cache location: ~/.claude/cache/plugins/skill-required/<project-slug>/
# Cache format: JSON file per skill name with last_read timestamp and tool_uses_since counter
set -euo pipefail

input="$(cat)"

# Extract the skill name from the tool input
# The Skill tool input has a "skill" field
skill_name="$(echo "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null || true)"

if [ -z "$skill_name" ]; then
  echo '{}'
  exit 0
fi

# Determine project slug for cache isolation
project_dir="${CLAUDE_PROJECT_DIR:-unknown}"
project_slug="$(echo "$project_dir" | sed 's|/|_|g' | sed 's|^_||')"

# Cache directory
cache_dir="$HOME/.claude/cache/plugins/skill-required/${project_slug}"
mkdir -p "$cache_dir"

# Write cache entry for this skill
cache_file="${cache_dir}/${skill_name}.json"
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
