#!/usr/bin/env bash
# sync-rules.sh — SessionStart hook for common-sense-beta plugin
#
# Thin wrapper that sets plugin identity and delegates to shared/lib/sync-rules.sh.
set -euo pipefail

PLUGIN_NAME="common-sense-beta"
PLUGIN_RULES_DIR="${CLAUDE_PLUGIN_ROOT}/rules"
LINK_NAME="common-sense-beta"

# shellcheck source=../../lib/plugin-config-read.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
# shellcheck source=../../lib/safe-settings-write.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
# shellcheck source=../../lib/sync-rules.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/sync-rules.sh"

sync_rules_run
