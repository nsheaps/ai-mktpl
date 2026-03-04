#!/usr/bin/env bash
# install-mise.sh — SessionStart hook for mise-tool plugin
#
# Installs or updates mise (tool version manager) for Claude Code web sessions.
# When install_to_project is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="mise-tool"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"

# --- Guards ---

plugin_is_enabled || { echo '{}'; exit 0; }
tool_is_web_session || { echo '{}'; exit 0; }

# --- Read config ---

version="$(plugin_get_config "version" "latest")"
auto_install="$(plugin_get_config "auto_install" "true")"
auto_install_tools="$(plugin_get_config "auto_install_tools" "true")"
auto_trust="$(plugin_get_config "auto_trust" "true")"

tool_resolve_install_dir

# --- Resolve mise binary ---

resolve_mise_bin() {
  local mise_bin="$INSTALL_DIR/mise"

  if [ "$auto_install" = "true" ]; then
    # Check if already installed via this mechanism
    if [ -x "$mise_bin" ]; then
      echo "${PLUGIN_NAME}: mise already installed at $mise_bin, checking for updates" >&2
      if [ "$version" = "latest" ]; then
        "$mise_bin" self-update 2>/dev/null || echo "${PLUGIN_NAME}: self-update skipped" >&2
      fi
    elif tool_is_available mise; then
      # Found on PATH from elsewhere — use it
      mise_bin="$(command -v mise)"
      echo "${PLUGIN_NAME}: mise found on PATH at $mise_bin" >&2
    else
      echo "${PLUGIN_NAME}: Installing mise to $INSTALL_DIR" >&2
      if [ "$version" = "latest" ]; then
        version="$(tool_resolve_github_version "jdx/mise" "2024.12.16")"
      fi
      local url="https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-linux-x64"
      if curl -fsSL "$url" -o "$mise_bin" 2>/dev/null; then
        chmod +x "$mise_bin"
        echo "${PLUGIN_NAME}: mise v${version} installed successfully" >&2
      else
        echo "${PLUGIN_NAME}: Failed to download mise v${version}" >&2
        echo '{}'; exit 0
      fi
    fi
    tool_ensure_path "$INSTALL_DIR"
  else
    # auto_install=false: use whatever mise is on PATH
    if tool_is_available mise; then
      mise_bin="$(command -v mise)"
      echo "${PLUGIN_NAME}: auto_install=false, using mise from PATH at $mise_bin" >&2
    else
      echo "${PLUGIN_NAME}: auto_install=false and mise not on PATH, skipping" >&2
      echo '{}'; exit 0
    fi
  fi

  echo "$mise_bin"
}

# --- Main ---

do_setup() {
  local mise_bin
  mise_bin="$(resolve_mise_bin)"

  # Always activate mise and persist to CLAUDE_ENV_FILE
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo 'eval "$('"$mise_bin"' activate bash)"' >> "$CLAUDE_ENV_FILE"
    echo "${PLUGIN_NAME}: Persisted mise activation to CLAUDE_ENV_FILE" >&2
  fi

  # Auto-trust
  if [ "$auto_trust" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    "$mise_bin" trust "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true
  fi

  # Auto-install tools
  if [ "$auto_install_tools" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    (cd "${CLAUDE_PROJECT_DIR:-.}" && GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" "$mise_bin" install -y 2>&1) \
      || echo "${PLUGIN_NAME}: tool installation had warnings" >&2
  fi
}

# --- Execute ---

tool_run_install do_setup
echo '{}'
