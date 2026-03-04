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
auto_install_tools="$(plugin_get_config "auto_install_tools" "true")"
auto_trust="$(plugin_get_config "auto_trust" "true")"

tool_resolve_install_dir

# --- Install/update function ---

do_install() {
  local mise_bin="$INSTALL_DIR/mise"

  # Check if already installed via this mechanism
  if [ -x "$mise_bin" ]; then
    echo "${PLUGIN_NAME}: mise already installed at $mise_bin, checking for updates" >&2
    if [ "$version" = "latest" ]; then
      "$mise_bin" self-update 2>/dev/null || echo "${PLUGIN_NAME}: self-update skipped" >&2
    fi
  else
    # Check if mise is available elsewhere on PATH
    if tool_is_available mise; then
      echo "${PLUGIN_NAME}: mise found on PATH ($(command -v mise)), skipping install" >&2
      echo '{}'; exit 0
    fi

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

  # Activate mise in shell
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo 'eval "$('"$mise_bin"' activate bash)"' >> "$CLAUDE_ENV_FILE"
  fi

  # Auto-trust
  if [ "$auto_trust" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    "$mise_bin" trust "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true
  fi

  # Auto-install tools
  if [ "$auto_install_tools" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    (cd "${CLAUDE_PROJECT_DIR:-.}" && "$mise_bin" install -y 2>&1) || echo "${PLUGIN_NAME}: tool installation had warnings" >&2
  fi
}

# --- Execute ---

tool_run_install do_install
echo '{}'
