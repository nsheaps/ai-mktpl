#!/usr/bin/env bash
# stop-guard.sh — Advisory warning when session ends with in-progress tasks
# Triggered by Stop hook (advisory only — does not block)
#
# Source: migrated from agent repo (was in .claude/rules as a hook, not a plugin hook).
# Commented out initially pending validation in plugin context — see spec.
#
# Exit code 0 = allow session to stop (advisory)

set -euo pipefail

# Read hook input (consume stdin)
cat > /dev/null

# TODO: Implement in-progress task detection via TaskList.
# Full implementation deferred to v1.1 pending reliable TaskList access from hooks.
# The hook is registered in hooks.json and runs, but currently exits 0 (no-op).

exit 0
