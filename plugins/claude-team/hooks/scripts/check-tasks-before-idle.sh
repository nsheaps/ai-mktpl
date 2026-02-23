#!/usr/bin/env bash
# check-tasks-before-idle.sh — TeammateIdle hook for claude-team plugin
#
# Prevents teammates from going idle when they have in_progress tasks.
# Forces them to move tasks back to pending (or complete them) first.
#
# Input (stdin JSON): { teammate_name, team_name, session_id, ... }
# Output: exit 0 to allow idle, exit 2 with stderr to reject and keep working
set -euo pipefail

input="$(cat)"

teammate_name="$(echo "$input" | jq -r '.teammate_name // empty' 2>/dev/null || true)"
team_name="$(echo "$input" | jq -r '.team_name // empty' 2>/dev/null || true)"

# If we can't determine the teammate or team, allow idle
if [ -z "$teammate_name" ] || [ -z "$team_name" ]; then
  exit 0
fi

# Find task directory for this team
task_dir="$HOME/.claude/tasks/${team_name}"
if [ ! -d "$task_dir" ]; then
  exit 0
fi

# Find in_progress tasks owned by this teammate
in_progress_tasks=()
for task_file in "$task_dir"/*.json; do
  [ -f "$task_file" ] || continue

  task_owner="$(jq -r '.owner // empty' "$task_file" 2>/dev/null || true)"
  task_status="$(jq -r '.status // empty' "$task_file" 2>/dev/null || true)"

  if [ "$task_owner" = "$teammate_name" ] && [ "$task_status" = "in_progress" ]; then
    task_id="$(jq -r '.id // empty' "$task_file" 2>/dev/null || true)"
    task_subject="$(jq -r '.subject // empty' "$task_file" 2>/dev/null || true)"
    in_progress_tasks+=("${task_id}: ${task_subject}")
  fi
done

# No in_progress tasks — allow idle
if [ ${#in_progress_tasks[@]} -eq 0 ]; then
  # Reset rejection counter on clean idle
  cache_dir="$HOME/.claude/cache/plugins/claude-team"
  cache_file="${cache_dir}/${team_name}_${teammate_name}_idle_rejections"
  rm -f "$cache_file" 2>/dev/null || true
  exit 0
fi

# Has in_progress tasks — check escape hatch counter
cache_dir="$HOME/.claude/cache/plugins/claude-team"
mkdir -p "$cache_dir"
cache_file="${cache_dir}/${team_name}_${teammate_name}_idle_rejections"

rejection_count=0
if [ -f "$cache_file" ]; then
  rejection_count="$(cat "$cache_file" 2>/dev/null || echo "0")"
  # Validate it's a number
  if ! [[ "$rejection_count" =~ ^[0-9]+$ ]]; then
    rejection_count=0
  fi
fi

# Escape hatch: after 3 rejections, allow with warning
if [ "$rejection_count" -ge 3 ]; then
  echo "WARNING: Allowing idle despite ${#in_progress_tasks[@]} in_progress task(s)." >&2
  echo "The following tasks are still in_progress and may be orphaned:" >&2
  for task in "${in_progress_tasks[@]}"; do
    echo "  - $task" >&2
  done
  # Reset counter
  rm -f "$cache_file" 2>/dev/null || true
  exit 0
fi

# Increment rejection counter
rejection_count=$((rejection_count + 1))
echo "$rejection_count" > "$cache_file"

# Reject idle — teammate must move tasks to pending first
{
  echo ""
  echo "You have ${#in_progress_tasks[@]} task(s) still marked as in_progress:"
  for task in "${in_progress_tasks[@]}"; do
    echo "  - $task"
  done
  echo ""
  echo "Before going idle, please either:"
  echo "  1. Complete these tasks and mark them as completed"
  echo "  2. Move them back to pending status using TaskUpdate"
  echo ""
  echo "You must not leave tasks in_progress when stopping work."
} >&2

exit 2
