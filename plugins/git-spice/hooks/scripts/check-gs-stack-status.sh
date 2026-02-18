#!/usr/bin/env bash
# Check if gs-stack-status is installed and print install instructions if not

if ! command -v gs-stack-status &>/dev/null; then
  echo "gs-stack-status is not installed. Install it with:"
  echo "  brew install nsheaps/devsetup/gs-stack-status"
  echo ""
  echo "gs-stack-status provides a terminal dashboard for git-spice stacked branch workflows."
fi
