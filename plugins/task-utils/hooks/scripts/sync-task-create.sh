#!/usr/bin/env bash
# sync-task-create.sh — Syncs a newly created task to configured providers
# Triggered by PostToolUse:TaskCreate hook
#
# Source: new hook — replaces todo-sync's TodoWrite sync with provider-based architecture.
# Providers are configured in plugins.settings.yaml under task-utils.providers.

set -euo pipefail

LOG_PREFIX="task-utils"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/log.sh"

# Read hook input from stdin
input=$(cat)

# Extract task info (if jq is available)
if ! command -v jq &>/dev/null; then
  log_warn "jq not found — skipping provider sync"
  exit 0
fi

# NOTE: `.tool_result` may need to be `.tool_response` when providers are implemented —
# verify the actual hook payload schema at that time.
task_id=$(echo "$input" | jq -r '.tool_result.taskId // empty' 2>/dev/null || echo "")
task_title=$(echo "$input" | jq -r '.tool_result.subject // empty' 2>/dev/null || echo "")

if [ -z "$task_id" ]; then
  # No task ID in output — nothing to sync
  exit 0
fi

# TODO: Read provider config from plugins.settings.yaml and invoke each enabled provider.
# FilesystemProvider and GitHubIssuesProvider will be implemented in the full v1 release.
# This stub exits 0 so the hook is registered and wired but does not fail.

log_info "TaskCreate sync stub: task_id=$task_id title='$task_title' (providers not yet implemented)"

exit 0
