#!/usr/bin/env bash
# sync-memory.sh — Auto-syncs memory files to a configured git repo
# Runs on SessionStart and TaskCompleted hooks
#
# If a git repo is configured (via brain.gitRepo setting), this script:
# 1. Pulls latest from the memory repo
# 2. Copies updated memory files (CLAUDE.md, rules, etc.) into the repo
# 3. Commits and pushes changes if any exist
#
# This provides persistent, version-controlled memory across sessions.

set -euo pipefail

PLUGIN_NAME="brain"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# Check if plugin is enabled
if ! plugin_is_enabled; then
  echo '{}'
  exit 0
fi

# Get the configured git repo path for memory storage
git_repo="$(plugin_get_config "gitRepo" "")"

if [ -z "$git_repo" ]; then
  # No git repo configured — skip sync silently
  echo '{}'
  exit 0
fi

# Expand ~ in path
git_repo="${git_repo/#\~/$HOME}"

# Validate the repo exists and is a git repo
if [ ! -d "$git_repo/.git" ]; then
  echo "brain: Warning — gitRepo '$git_repo' is not a git repository" >&2
  echo '{}'
  exit 0
fi

# Get memory sources to sync
# Default: ~/.claude/CLAUDE.md and project CLAUDE.md
memory_sources=()
while IFS= read -r source; do
  [ -n "$source" ] && memory_sources+=("$source")
done < <(plugin_get_config_array "memorySources")

# If no sources configured, use sensible defaults
if [ ${#memory_sources[@]} -eq 0 ]; then
  memory_sources=(
    "${HOME}/.claude/CLAUDE.md"
    "${HOME}/.claude/history.jsonl"
  )
  # Add project CLAUDE.md if in a project
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "${CLAUDE_PROJECT_DIR}/CLAUDE.md" ]; then
    memory_sources+=("${CLAUDE_PROJECT_DIR}/CLAUDE.md")
  fi
fi

# Branch for memory storage
branch="$(plugin_get_config "gitBranch" "main")"

# Check for uncommitted changes in the memory repo
if [ -n "$(cd "$git_repo" && git status --porcelain 2>/dev/null)" ]; then
  echo "brain: Warning — memory repo has uncommitted changes, skipping sync" >&2
  echo '{}'
  exit 0
fi

# Pull latest from remote (best-effort)
(
  cd "$git_repo"
  git fetch origin "$branch" 2>/dev/null || true
  git checkout "$branch" 2>/dev/null || true
  git pull origin "$branch" --ff-only 2>/dev/null || true
) &>/dev/null || true

# Copy memory files into the repo
changes_made=false
memory_dir="${git_repo}/memory"
mkdir -p "$memory_dir"

for source in "${memory_sources[@]}"; do
  source="${source/#\~/$HOME}"
  if [ -f "$source" ]; then
    # Create a safe filename from the source path
    # e.g., /home/user/.claude/CLAUDE.md -> home__user__.claude__CLAUDE.md
    # Uses __ to avoid collisions (e.g., /a/b-c.md vs /a/b/c.md)
    safe_name="$(echo "$source" | sed 's|^/||; s|/|__|g')"
    dest="${memory_dir}/${safe_name}"

    # Only copy if content differs
    if [ ! -f "$dest" ] || ! diff -q "$source" "$dest" &>/dev/null; then
      cp "$source" "$dest"
      changes_made=true
    fi
  fi
done

# Commit and push if there are changes
if [ "$changes_made" = true ]; then
  (
    cd "$git_repo"
    git add memory/

    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    session_id="${CLAUDE_SESSION_ID:-unknown}"

    git commit -m "brain: auto-sync memory files

Session: ${session_id}
Timestamp: ${timestamp}
Sources: ${memory_sources[*]}" 2>/dev/null || true

    git push origin "$branch" 2>/dev/null || true
  ) &>/dev/null || true

  echo "brain: Memory synced to ${git_repo}" >&2
fi

echo '{}'
