#!/usr/bin/env bash
# session-start.sh — Injects task-awareness context into the session
# Triggered by SessionStart hook
#
# Source: migrated and extended from todo-plus-plus v0.1.5 SessionStart hook

set -euo pipefail

# Read hook input (consume stdin)
cat > /dev/null

# Emit session context as a systemMessage via JSON output
cat <<'EOF'
{"systemMessage": "IMPORTANT SESSION CONTEXT: You may be running in an ephemeral session (a sub-agent, teammate, or temporary context). The Tasks system (TaskCreate, TaskUpdate, TaskList) is for tracking YOUR local work items within THIS session only. Do NOT use Tasks for persistent project tracking, feature backlogs, or cross-session work items. Those belong in external systems (GitHub Issues, Linear, etc.). Tasks are session-scoped and will not survive session end. Also: when you complete a task, ALWAYS commit and push your changes before marking it complete. Use TaskCreate on EVERY action request from the user — even simple, one-off tasks. Always keep your task list up to date."}
EOF

exit 0
