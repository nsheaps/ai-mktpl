#!/usr/bin/env bash
# install-gh.sh — SessionStart hook for gh-tool plugin
#
# Installs or updates GitHub CLI (gh) for Claude Code web sessions.
# When install_to_project is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="gh-tool"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"

# --- Guards ---

plugin_is_enabled || { echo '{}'; exit 0; }
tool_is_web_session || { echo '{}'; exit 0; }

# --- Read config ---

version="$(plugin_get_config "version" "latest")"
auto_install="$(plugin_get_config "auto_install" "true")"
auto_auth_check="$(plugin_get_config "auto_auth_check" "true")"

tool_resolve_install_dir

# --- Install/update function ---

do_install() {
  local gh_bin

  if [ "$auto_install" = "false" ]; then
    # Skip installation — gh is managed externally (e.g. via mise)
    echo "${PLUGIN_NAME}: auto_install=false, skipping installation" >&2
    if tool_is_available gh; then
      gh_bin="$(command -v gh)"
    else
      echo "${PLUGIN_NAME}: gh not on PATH yet (may be installed later by mise), skipping auth check" >&2
      return
    fi
  else
    gh_bin="$INSTALL_DIR/gh"

    # Check if already installed via this mechanism
    if [ -x "$gh_bin" ]; then
      echo "${PLUGIN_NAME}: gh already installed at $gh_bin" >&2
      if [ "$version" = "latest" ]; then
        echo "${PLUGIN_NAME}: Checking for updates..." >&2
        local current_version
        current_version="$("$gh_bin" version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")"
        local latest_version
        latest_version="$(tool_resolve_github_version "cli/cli" "2.87.3")"
        if [ "$current_version" = "$latest_version" ]; then
          echo "${PLUGIN_NAME}: gh $current_version is already latest" >&2
          gh_bin="$INSTALL_DIR/gh"
        else
          version="$latest_version"
          echo "${PLUGIN_NAME}: Updating from $current_version to $latest_version" >&2
        fi
      fi
    else
      # Check if gh is available elsewhere on PATH
      if tool_is_available gh; then
        echo "${PLUGIN_NAME}: gh found on PATH ($(command -v gh)), skipping install" >&2
        gh_bin="$(command -v gh)"
      else
        echo "${PLUGIN_NAME}: Installing gh to $INSTALL_DIR" >&2

        if [ "$version" = "latest" ]; then
          version="$(tool_resolve_github_version "cli/cli" "2.87.3")"
        fi

        # Download and extract
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        local archive="gh_${version}_linux_amd64.tar.gz"
        local url="https://github.com/cli/cli/releases/download/v${version}/${archive}"

        if curl -fsSL "$url" -o "$tmp_dir/$archive" 2>/dev/null; then
          tar -xf "$tmp_dir/$archive" -C "$tmp_dir"
          cp "$tmp_dir/gh_${version}_linux_amd64/bin/gh" "$gh_bin"
          chmod +x "$gh_bin"
          echo "${PLUGIN_NAME}: gh v${version} installed successfully" >&2
        else
          echo "${PLUGIN_NAME}: Failed to download gh v${version}" >&2
          rm -rf "$tmp_dir"
          echo '{}'; exit 0
        fi
        rm -rf "$tmp_dir"

        tool_ensure_path "$INSTALL_DIR"
      fi
    fi
  fi

  # Auth check
  if [ "$auto_auth_check" = "true" ]; then
    "$gh_bin" auth status 2>&1 || echo "${PLUGIN_NAME}: gh auth not configured" >&2
  fi
}

# --- Execute ---

tool_run_install do_install
echo '{}'
