#!/usr/bin/env bash
# sync-task-update.sh — Syncs task status changes to configured providers
# Triggered by PostToolUse:TaskUpdate hook
#
# Source: new hook — provider-based architecture (see spec.md).
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

task_id=$(echo "$input" | jq -r '.tool_input.id // empty' 2>/dev/null || echo "")
new_status=$(echo "$input" | jq -r '.tool_input.status // empty' 2>/dev/null || echo "")

if [ -z "$task_id" ]; then
  # No task ID in input — nothing to sync
  exit 0
fi

# TODO: Read provider config from plugins.settings.yaml and invoke each enabled provider.
# FilesystemProvider and GitHubIssuesProvider will be implemented in the full v1 release.
# This stub exits 0 so the hook is registered and wired but does not fail.

log_info "TaskUpdate sync stub: task_id=$task_id status='$new_status' (providers not yet implemented)"

exit 0
