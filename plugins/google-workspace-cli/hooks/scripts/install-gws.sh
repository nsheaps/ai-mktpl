#!/usr/bin/env bash
# install-gws.sh — SessionStart hook for google-workspace-cli plugin
#
# Installs or updates the Google Workspace CLI (gws) for Claude Code web sessions.
# Uses npm to install @googleworkspace/cli, or downloads a pre-compiled binary
# from GitHub releases as a fallback.
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

  # Check if already installed
  if [ -x "$gws_bin" ]; then
    echo "${PLUGIN_NAME}: gws already installed at $gws_bin" >&2
    echo "$gws_bin"
    return 0
  fi

  # Check if available on PATH
  if tool_is_available gws; then
    gws_bin="$(command -v gws)"
    echo "${PLUGIN_NAME}: gws found on PATH at $gws_bin" >&2
    echo "$gws_bin"
    return 0
  fi

  # Try npm install first (preferred method)
  echo "${PLUGIN_NAME}: Installing Google Workspace CLI via npm..." >&2
  if tool_is_available npm; then
    local npm_prefix="$INSTALL_DIR/npm-global"
    mkdir -p "$npm_prefix"

    local pkg="@googleworkspace/cli"
    if [ "$version" != "latest" ]; then
      pkg="${pkg}@${version}"
    fi

    if npm install -g --prefix "$npm_prefix" "$pkg" 2>&1 >&2; then
      # npm installs the binary to $prefix/bin/gws
      local npm_bin="$npm_prefix/bin/gws"
      if [ -x "$npm_bin" ]; then
        # Symlink into INSTALL_DIR for consistency
        ln -sf "$npm_bin" "$gws_bin"
        echo "${PLUGIN_NAME}: gws installed via npm successfully" >&2
        tool_ensure_path "$INSTALL_DIR"
        echo "$gws_bin"
        return 0
      fi
    fi
    echo "${PLUGIN_NAME}: npm install failed, trying binary download..." >&2
  fi

  # Fallback: download pre-compiled binary from GitHub releases
  if [ "$version" = "latest" ]; then
    version="$(tool_resolve_github_version "googleworkspace/cli" "0.5.0")"
  fi

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

  local url="https://github.com/googleworkspace/cli/releases/download/v${version}/gws-linux-${arch}"
  echo "${PLUGIN_NAME}: Downloading gws v${version} from $url" >&2
  if curl -fsSL "$url" -o "$gws_bin" 2>/dev/null; then
    chmod +x "$gws_bin"
    echo "${PLUGIN_NAME}: gws v${version} installed successfully" >&2
  else
    echo "${PLUGIN_NAME}: Failed to download gws v${version}" >&2
    return 1
  fi

  tool_ensure_path "$INSTALL_DIR"
  echo "$gws_bin"
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
