#!/usr/bin/env bash
# install-gh.sh — SessionStart hook for github plugin
#
# Installs or updates GitHub CLI (gh) for Claude Code web sessions.
# When install_to_project is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="github"
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

# --- Download helper ---

# Downloads gh at the given version to $INSTALL_DIR, adds to PATH.
# Prints the binary path to stdout. Returns 1 on failure.
download_gh() {
  local target_version="$1"
  local gh_bin="$INSTALL_DIR/gh"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local archive="gh_${target_version}_linux_amd64.tar.gz"
  local url="https://github.com/cli/cli/releases/download/v${target_version}/${archive}"

  if curl -fsSL "$url" -o "$tmp_dir/$archive" 2>/dev/null; then
    tar -xf "$tmp_dir/$archive" -C "$tmp_dir"
    cp "$tmp_dir/gh_${target_version}_linux_amd64/bin/gh" "$gh_bin"
    chmod +x "$gh_bin"
    rm -rf "$tmp_dir"
    echo "${PLUGIN_NAME}: gh v${target_version} installed successfully" >&2
    tool_ensure_path "$INSTALL_DIR"
    echo "$gh_bin"
  else
    echo "${PLUGIN_NAME}: Failed to download gh v${target_version}" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
}

# --- Resolve gh binary ---

# Prints the path to a usable gh binary, or returns 1 if unavailable.
resolve_gh_bin() {
  if [ "$auto_install" = "false" ]; then
    if tool_is_available gh; then
      echo "${PLUGIN_NAME}: auto_install=false, using gh from PATH" >&2
      command -v gh
    else
      echo "${PLUGIN_NAME}: auto_install=false and gh not on PATH, skipping" >&2
      return 1
    fi
    return
  fi

  local gh_bin="$INSTALL_DIR/gh"

  if [ -x "$gh_bin" ]; then
    # Already installed — check for updates if version=latest
    if [ "$version" = "latest" ]; then
      local current_version latest_version
      current_version="$("$gh_bin" version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")"
      latest_version="$(tool_resolve_github_version "cli/cli" "2.87.3")"
      if [ "$current_version" = "$latest_version" ]; then
        echo "${PLUGIN_NAME}: gh $current_version is already latest" >&2
        echo "$gh_bin"
      else
        echo "${PLUGIN_NAME}: Updating gh from $current_version to $latest_version" >&2
        download_gh "$latest_version"
      fi
    else
      echo "$gh_bin"
    fi
  elif tool_is_available gh; then
    echo "${PLUGIN_NAME}: gh found on PATH ($(command -v gh)), skipping install" >&2
    command -v gh
  else
    echo "${PLUGIN_NAME}: Installing gh to $INSTALL_DIR" >&2
    local install_version="$version"
    if [ "$install_version" = "latest" ]; then
      install_version="$(tool_resolve_github_version "cli/cli" "2.87.3")"
    fi
    download_gh "$install_version"
  fi
}

# --- Main ---

do_install() {
  local gh_bin
  gh_bin="$(resolve_gh_bin)" || { echo '{}'; exit 0; }

  if [ "$auto_auth_check" = "true" ]; then
    "$gh_bin" auth status 2>&1 || echo "${PLUGIN_NAME}: gh auth not configured" >&2
  fi
}

# --- Execute ---

tool_run_install do_install
echo '{}'
