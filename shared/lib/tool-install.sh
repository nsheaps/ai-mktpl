#!/usr/bin/env bash
# tool-install.sh — Shared library for installing tools to project-local bin/.local
#
# Provides helpers for the project-local binary installation pattern:
#   - Resolve install directory from plugin config
#   - Add directory to PATH via CLAUDE_ENV_FILE
#   - Check if a tool is already available
#   - Resolve latest GitHub release version
#
# Usage:
#   PLUGIN_NAME="my-plugin"
#   source "path/to/plugin-config-read.sh"
#   source "path/to/tool-install.sh"
#
#   tool_resolve_install_dir          # Sets INSTALL_DIR
#   tool_ensure_path "$INSTALL_DIR"   # Adds to PATH if needed
#   tool_is_available "mytool"        # Check if on PATH already
#   ver="$(tool_resolve_github_version "owner/repo" "1.0.0")"
#
# Requires: plugin-config-read.sh must be sourced first.
# Note: Plugins symlink this file into their own lib/ directory.
# Symlinked content is resolved and copied on plugin install.

# Guard against double-sourcing
if [ "${_TOOL_INSTALL_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_TOOL_INSTALL_LOADED="true"

# Check if running in a web session. Returns 0 if web, 1 if local.
tool_is_web_session() {
  [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]
}

# Resolve the install directory based on plugin config.
# Reads "install_to_project" config key.
# Sets INSTALL_DIR as a global variable and creates the directory.
tool_resolve_install_dir() {
  local install_to_project
  install_to_project="$(plugin_get_config "install_to_project" "true")"

  if [ "$install_to_project" = "true" ]; then
    INSTALL_DIR="${CLAUDE_PROJECT_DIR:-.}/bin/.local"
  else
    INSTALL_DIR="$HOME/.local/bin"
  fi

  mkdir -p "$INSTALL_DIR"
}

# Add a directory to PATH via CLAUDE_ENV_FILE if not already present.
# Also exports it for immediate use in the current script.
# Args: $1=directory (defaults to $INSTALL_DIR)
tool_ensure_path() {
  local dir="${1:-$INSTALL_DIR}"

  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    if ! echo "$PATH" | tr ':' '\n' | grep -qF "$dir"; then
      echo "export PATH=\"$dir:\$PATH\"" >> "$CLAUDE_ENV_FILE"
    fi
  fi

  export PATH="$dir:$PATH"
}

# Check if a tool is already available on PATH.
# Args: $1=tool_name
# Returns: 0 if available, 1 if not
tool_is_available() {
  local tool="$1"
  command -v "$tool" &>/dev/null
}

# Resolve the latest version of a GitHub release.
# Tries gh API first, falls back to curl, then to a hardcoded fallback.
# Args: $1=repo (owner/repo) $2=fallback_version
# Returns: version string via stdout (without leading "v")
tool_resolve_github_version() {
  local repo="$1" fallback="$2"
  local version=""

  # Try gh API
  if command -v gh &>/dev/null; then
    version="$(gh api "repos/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//' || true)"
  fi

  # Try curl fallback
  if [ -z "$version" ]; then
    version="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
      | grep '"tag_name"' \
      | sed 's/.*"v\{0,1\}\([^"]*\)".*/\1/' || true)"
  fi

  # Hardcoded fallback
  if [ -z "$version" ]; then
    echo "${PLUGIN_NAME}: Could not determine latest version, using fallback $fallback" >&2
    version="$fallback"
  fi

  echo "$version"
}

# Run a function in the background or foreground based on plugin config.
# Reads "background_install" config key.
# Args: $1=function_name
tool_run_install() {
  local func="$1"
  local background
  background="$(plugin_get_config "background_install" "false")"

  if [ "$background" = "true" ]; then
    "$func" &
    echo "${PLUGIN_NAME}: Installation running in background" >&2
  else
    "$func"
  fi
}
