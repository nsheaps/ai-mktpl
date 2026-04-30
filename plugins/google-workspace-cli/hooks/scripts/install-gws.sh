#!/usr/bin/env bash
# install-gws.sh — SessionStart hook for google-workspace-cli plugin
#
# Installs or updates the Google Workspace CLI (gws), then runs auth check.
# Prefers mise (ubi backend) for installation, falls back to direct binary download
# from GitHub releases.
set -euo pipefail

PLUGIN_NAME="google-workspace-cli"


# --- Source shared libs from shared-lib plugin's persistent data dir ---
#
# shared-lib (declared in plugin.json `dependencies`) copies its lib/*.sh
# files into ${CLAUDE_PLUGIN_DATA}/lib on SessionStart. We resolve its data
# dir by stripping our own data-dir name and appending shared-lib's id.
# Plugin data dir IDs are deterministic: `{plugin-name}-{marketplace-name}`.
# See https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
#
# When CLAUDE_PLUGIN_DATA is unset (e.g. when this script is invoked
# outside a Claude Code hook), fall back to the known path.
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

# Wait up to ~10s for a shared-lib file to appear (handles parallel
# SessionStart hooks where shared-lib's copy may not have completed yet).
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[google-workspace-cli] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "plugin-config-read.sh"
_wait_for_shared_lib "tool-install.sh"
_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/tool-install.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }
# NOTE: No early exit when gws is on PATH — auth check must still run.
# resolve_gws_bin() skips the download internally.

# --- Read config ---

version="$(plugin_get_config "version" "latest")"
auto_install="$(plugin_get_config "autoInstall" "true")"
auto_auth="$(plugin_get_config "autoAuth" "false")"

tool_resolve_install_dir

# --- Download helper ---

# Downloads gws tarball from GitHub releases and extracts the binary.
# Prints the binary path to stdout. Returns 1 on failure.
download_gws() {
  local target_version="$1"
  local gws_bin="$INSTALL_DIR/gws"

  local triple
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64)  triple="x86_64-unknown-linux-gnu" ;;
    aarch64) triple="aarch64-unknown-linux-gnu" ;;
    arm64)   triple="aarch64-unknown-linux-gnu" ;;
    *)
      log_error "Unsupported architecture: $arch"
      return 1
      ;;
  esac

  local archive="gws-${triple}.tar.gz"
  local url="https://github.com/googleworkspace/cli/releases/download/v${target_version}/${archive}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  log_info "Downloading gws v${target_version} from $url"
  if curl -fsSL "$url" -o "$tmp_dir/$archive" 2>/dev/null; then
    tar -xf "$tmp_dir/$archive" -C "$tmp_dir"
    # Find the gws binary in the extracted contents
    local extracted_bin
    extracted_bin="$(find "$tmp_dir" -name "gws" -type f -perm -u+x 2>/dev/null | head -1)"
    if [ -z "$extracted_bin" ]; then
      # Try without executable check (permissions may not survive tar)
      extracted_bin="$(find "$tmp_dir" -name "gws" -type f 2>/dev/null | head -1)"
    fi
    if [ -n "$extracted_bin" ]; then
      cp "$extracted_bin" "$gws_bin"
      chmod +x "$gws_bin"
      rm -rf "$tmp_dir"
      log_info "gws v${target_version} installed successfully"
      tool_ensure_path "$INSTALL_DIR"
      echo "$gws_bin"
    else
      rm -rf "$tmp_dir"
      log_error "Failed to find gws binary in archive"
      return 1
    fi
  else
    rm -rf "$tmp_dir"
    log_error "Failed to download gws v${target_version}"
    return 1
  fi
}

# --- Resolve gws binary ---

resolve_gws_bin() {
  local gws_bin="$INSTALL_DIR/gws"

  if [ "$auto_install" != "true" ]; then
    if tool_is_available gws; then
      gws_bin="$(command -v gws)"
      log_info "autoInstall=false, using gws from PATH at $gws_bin"
    else
      log_info "autoInstall=false and gws not on PATH, skipping"
      return 1
    fi
    echo "$gws_bin"
    return 0
  fi

  # Check if already installed in INSTALL_DIR
  if [ -x "$gws_bin" ]; then
    tool_ensure_path "$INSTALL_DIR"
    log_info "gws already installed at $gws_bin"
    echo "$gws_bin"
    return 0
  fi

  # Check if available on PATH (e.g. installed by mise globally)
  if tool_is_available gws; then
    gws_bin="$(command -v gws)"
    log_info "gws found on PATH at $gws_bin"
    echo "$gws_bin"
    return 0
  fi

  # Resolve version for installation
  local install_version="$version"
  if [ "$install_version" = "latest" ]; then
    install_version="$(tool_resolve_github_version "googleworkspace/cli" "0.11.0")"
  fi

  # Try mise with ubi backend (preferred method)
  if tool_is_available mise; then
    log_info "Installing gws via mise (ubi backend)..."
    local mise_spec="ubi:googleworkspace/cli"
    if [ "$install_version" != "latest" ]; then
      mise_spec="${mise_spec}@${install_version}"
    fi
    if mise use -g "$mise_spec" >&2; then
      if tool_is_available gws; then
        gws_bin="$(command -v gws)"
        log_info "gws installed via mise at $gws_bin"
        echo "$gws_bin"
        return 0
      fi
    fi
    log_warn "mise install failed, trying direct binary download..."
  fi

  # Fallback: download pre-compiled binary from GitHub releases
  log_info "Installing gws to $INSTALL_DIR"
  download_gws "$install_version"
}

# --- Main ---

do_setup() {
  local gws_bin
  gws_bin="$(resolve_gws_bin)" || { hook_log "gws not available, skipping"; hook_respond; exit 0; }

  # Persist PATH for future tool calls
  tool_ensure_path "$INSTALL_DIR"

  # Check auth status
  if [ "$auto_auth" = "true" ]; then
    if ! "$gws_bin" auth status &>/dev/null; then
      hook_log "gws auth not configured. Run 'gws auth setup' and 'gws auth login' to authenticate."
    fi
  fi

  hook_log "Google Workspace CLI is ready"
}

# --- Execute ---

tool_run_install do_setup
hook_log_cleanup
hook_respond
