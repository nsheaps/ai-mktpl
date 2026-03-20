#!/usr/bin/env bash
# Check if gs-stack-status is installed and print install instructions if not

# shellcheck source=../../lib/hook-output.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-output.sh"

if ! command -v gs-stack-status &>/dev/null; then
  hook_msg "git-spice: gs-stack-status is not installed. Install it with:
  brew install nsheaps/devsetup/gs-stack-status

gs-stack-status provides a terminal dashboard for git-spice stacked branch workflows."
else
  hook_msg "git-spice: gs-stack-status available"
fi
