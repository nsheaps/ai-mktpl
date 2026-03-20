#!/usr/bin/env bash
# Ensure git pre-commit hooks are active for this session.
# This configures core.hooksPath to use the repo's .githooks/ directory,
# which runs prettier on staged files before each commit.
set -euo pipefail

CURRENT=$(git config --get core.hooksPath 2>/dev/null || true)
if [ "$CURRENT" != ".githooks" ]; then
  git config core.hooksPath .githooks
  echo "[00-setup-git-hooks] Configured core.hooksPath=.githooks"
fi
