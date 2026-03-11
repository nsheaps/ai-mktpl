#!/usr/bin/env bash
# install-gws.sh — SessionStart hook for google-workspace-cli plugin
#
# Installs or updates the Google Workspace CLI (gws) for Claude Code web sessions.
# Prefers mise (ubi backend) for installation, falls back to direct binary download
# from GitHub releases.
set -euo pipefail

PLUGIN_NAME="google-workspace-cli"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"

# --- Guards ---

plugin_is_enabled || { echo '{}'; exit 0; }
tool_is_web_session || { echo '{}'; exit 0; }

# --- Read config ---

version="$(plugin_get_config "version" "latest")"
auto_install="$(plugin_get_config "autoInstall" "true")"
auto_auth="$(plugin_get_config "autoAuth" "false")"

tool_resolve_install_dir

# --- Download helper ---

# Downloads gws binary directly from GitHub releases.
# Prints the binary path to stdout. Returns 1 on failure.
download_gws() {
  local target_version="$1"
  local gws_bin="$INSTALL_DIR/gws"

  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64)  arch="x64" ;;
    aarch64) arch="arm64" ;;
    arm64)   arch="arm64" ;;
    *)
      echo "${PLUGIN_NAME}: Unsupported architecture: $arch" >&2
      return 1
      ;;
  esac

  local url="https://github.com/googleworkspace/cli/releases/download/v${target_version}/gws-linux-${arch}"
  echo "${PLUGIN_NAME}: Downloading gws v${target_version} from $url" >&2
  if curl -fsSL "$url" -o "$gws_bin" 2>/dev/null; then
    chmod +x "$gws_bin"
    echo "${PLUGIN_NAME}: gws v${target_version} installed successfully" >&2
    tool_ensure_path "$INSTALL_DIR"
    echo "$gws_bin"
  else
    echo "${PLUGIN_NAME}: Failed to download gws v${target_version}" >&2
    return 1
  fi
}

# --- Resolve gws binary ---

resolve_gws_bin() {
  local gws_bin="$INSTALL_DIR/gws"

  if [ "$auto_install" != "true" ]; then
    if tool_is_available gws; then
      gws_bin="$(command -v gws)"
      echo "${PLUGIN_NAME}: autoInstall=false, using gws from PATH at $gws_bin" >&2
    else
      echo "${PLUGIN_NAME}: autoInstall=false and gws not on PATH, skipping" >&2
      return 1
    fi
    echo "$gws_bin"
    return 0
  fi

  # Check if already installed in INSTALL_DIR
  if [ -x "$gws_bin" ]; then
    tool_ensure_path "$INSTALL_DIR"
    echo "${PLUGIN_NAME}: gws already installed at $gws_bin" >&2
    echo "$gws_bin"
    return 0
  fi

  # Check if available on PATH (e.g. installed by mise globally)
  if tool_is_available gws; then
    gws_bin="$(command -v gws)"
    echo "${PLUGIN_NAME}: gws found on PATH at $gws_bin" >&2
    echo "$gws_bin"
    return 0
  fi

  # Resolve version for installation
  local install_version="$version"
  if [ "$install_version" = "latest" ]; then
    install_version="$(tool_resolve_github_version "googleworkspace/cli" "0.5.0")"
  fi

  # Try mise with ubi backend (preferred method)
  if tool_is_available mise; then
    echo "${PLUGIN_NAME}: Installing gws via mise (ubi backend)..." >&2
    local mise_spec="ubi:googleworkspace/cli"
    if [ "$install_version" != "latest" ]; then
      mise_spec="${mise_spec}@${install_version}"
    fi
    if mise use -g "$mise_spec" 2>&1 >&2; then
      if tool_is_available gws; then
        gws_bin="$(command -v gws)"
        echo "${PLUGIN_NAME}: gws installed via mise at $gws_bin" >&2
        echo "$gws_bin"
        return 0
      fi
    fi
    echo "${PLUGIN_NAME}: mise install failed, trying direct binary download..." >&2
  fi

  # Fallback: download pre-compiled binary from GitHub releases
  echo "${PLUGIN_NAME}: Installing gws to $INSTALL_DIR" >&2
  download_gws "$install_version"
}

# --- Main ---

do_setup() {
  local gws_bin
  gws_bin="$(resolve_gws_bin)" || { echo '{}'; exit 0; }

  # Persist PATH for future tool calls
  tool_ensure_path "$INSTALL_DIR"

  # Check auth status
  if [ "$auto_auth" = "true" ]; then
    if ! "$gws_bin" auth status &>/dev/null; then
      echo "${PLUGIN_NAME}: gws auth not configured. Run 'gws auth setup' and 'gws auth login' to authenticate." >&2
    fi
  fi

  echo "${PLUGIN_NAME}: Google Workspace CLI is ready" >&2
}

# --- Execute ---

tool_run_install do_setup
echo '{}'
