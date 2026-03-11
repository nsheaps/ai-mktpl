#!/usr/bin/env bash
# install-op.sh — SessionStart hook for 1pass plugin
#
# Installs or updates 1Password CLI (op) and op-exec for Claude Code web sessions.
# When install_to_project is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="1pass"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"

# --- Guards ---

plugin_is_enabled || { echo '{}'; exit 0; }
tool_is_web_session || { echo '{}'; exit 0; }

# --- Read config ---

auto_install="$(plugin_get_config "auto_install" "false")"
op_version="$(plugin_get_config "op_version" "latest")"
install_op_exec="$(plugin_get_config "install_op_exec" "false")"
op_exec_version="$(plugin_get_config "op_exec_version" "latest")"

tool_resolve_install_dir

# --- Platform detection ---

detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$arch" in
    x86_64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    i386|i686) arch="386" ;;
    *) echo "${PLUGIN_NAME}: Unsupported architecture: $arch" >&2; return 1 ;;
  esac

  case "$os" in
    linux|darwin) ;;
    *) echo "${PLUGIN_NAME}: Unsupported OS: $os" >&2; return 1 ;;
  esac

  DETECTED_OS="$os"
  DETECTED_ARCH="$arch"
}

detect_platform || { echo '{}'; exit 0; }

# --- Version resolution ---

# Resolve the latest op CLI version from 1Password's update endpoint.
# 1Password/cli is not a public GitHub repo, so we can't use tool_resolve_github_version.
# Falls back to a hardcoded version on failure.
resolve_latest_op_version() {
  local fallback="2.32.1"
  local version=""
  version="$(curl -fsSL "https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N" 2>/dev/null \
    | grep -o '"version":"[^"]*"' | sed 's/"version":"//;s/"//' || true)"
  if [ -z "$version" ]; then
    echo "${PLUGIN_NAME}: Could not determine latest op version, using fallback $fallback" >&2
    version="$fallback"
  fi
  echo "$version"
}

# --- Download helpers ---

download_op() {
  local target_version="$1"
  local op_bin="$INSTALL_DIR/op"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local archive="op_${DETECTED_OS}_${DETECTED_ARCH}_v${target_version}.zip"
  local url="https://cache.agilebits.com/dist/1P/op2/pkg/v${target_version}/${archive}"

  if curl -fsSL "$url" -o "$tmp_dir/$archive" 2>/dev/null; then
    if command -v unzip >/dev/null 2>&1; then
      unzip -o -q "$tmp_dir/$archive" -d "$tmp_dir"
    else
      # Fallback: use python to unzip
      python3 -c "import zipfile; zipfile.ZipFile('$tmp_dir/$archive').extractall('$tmp_dir')"
    fi
    cp "$tmp_dir/op" "$op_bin"
    chmod +x "$op_bin"
    rm -rf "$tmp_dir"
    echo "${PLUGIN_NAME}: op v${target_version} installed successfully" >&2
    tool_ensure_path "$INSTALL_DIR"
    echo "$op_bin"
  else
    echo "${PLUGIN_NAME}: Failed to download op v${target_version}" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
}

download_op_exec() {
  local target_version="$1"
  local op_exec_bin="$INSTALL_DIR/op-exec"
  local url="https://github.com/nsheaps/op-exec/releases/download/v${target_version}/op-exec-${DETECTED_OS}-${DETECTED_ARCH}"

  if curl -fsSL "$url" -o "$op_exec_bin" 2>/dev/null; then
    chmod +x "$op_exec_bin"
    echo "${PLUGIN_NAME}: op-exec v${target_version} installed successfully" >&2
    tool_ensure_path "$INSTALL_DIR"
    echo "$op_exec_bin"
  else
    echo "${PLUGIN_NAME}: Failed to download op-exec v${target_version}" >&2
    return 1
  fi
}

# --- Resolve op binary ---

resolve_op_bin() {
  if [ "$auto_install" = "false" ]; then
    if tool_is_available op; then
      echo "${PLUGIN_NAME}: auto_install=false, using op from PATH" >&2
      command -v op
    else
      echo "${PLUGIN_NAME}: auto_install=false and op not on PATH, skipping" >&2
      return 1
    fi
    return
  fi

  local op_bin="$INSTALL_DIR/op"

  if [ -x "$op_bin" ]; then
    if [ "$op_version" = "latest" ]; then
      local current_version latest_version
      current_version="$("$op_bin" --version 2>/dev/null || echo "unknown")"
      latest_version="$(resolve_latest_op_version)"
      if [ "$current_version" = "$latest_version" ]; then
        echo "${PLUGIN_NAME}: op $current_version is already latest" >&2
        echo "$op_bin"
      else
        echo "${PLUGIN_NAME}: Updating op from $current_version to $latest_version" >&2
        download_op "$latest_version"
      fi
    else
      echo "$op_bin"
    fi
  elif tool_is_available op; then
    echo "${PLUGIN_NAME}: op found on PATH ($(command -v op)), skipping install" >&2
    command -v op
  else
    echo "${PLUGIN_NAME}: Installing op to $INSTALL_DIR" >&2
    local install_version="$op_version"
    if [ "$install_version" = "latest" ]; then
      install_version="$(resolve_latest_op_version)"
    fi
    download_op "$install_version"
  fi
}

# --- Resolve op-exec binary ---

resolve_op_exec_bin() {
  if [ "$install_op_exec" = "false" ]; then
    if tool_is_available op-exec; then
      echo "${PLUGIN_NAME}: install_op_exec=false, using op-exec from PATH" >&2
      command -v op-exec
    else
      echo "${PLUGIN_NAME}: install_op_exec=false and op-exec not on PATH, skipping" >&2
      return 1
    fi
    return
  fi

  local op_exec_bin="$INSTALL_DIR/op-exec"

  if [ -x "$op_exec_bin" ]; then
    if [ "$op_exec_version" = "latest" ]; then
      local current_version latest_version
      current_version="$("$op_exec_bin" --version 2>/dev/null || echo "unknown")"
      latest_version="$(tool_resolve_github_version "nsheaps/op-exec" "0.0.1")"
      if [ "$current_version" = "$latest_version" ]; then
        echo "${PLUGIN_NAME}: op-exec $current_version is already latest" >&2
        echo "$op_exec_bin"
      else
        echo "${PLUGIN_NAME}: Updating op-exec from $current_version to $latest_version" >&2
        download_op_exec "$latest_version"
      fi
    else
      echo "$op_exec_bin"
    fi
  elif tool_is_available op-exec; then
    echo "${PLUGIN_NAME}: op-exec found on PATH ($(command -v op-exec)), skipping install" >&2
    command -v op-exec
  else
    echo "${PLUGIN_NAME}: Installing op-exec to $INSTALL_DIR" >&2
    local install_version="$op_exec_version"
    if [ "$install_version" = "latest" ]; then
      install_version="$(tool_resolve_github_version "nsheaps/op-exec" "0.0.1")"
    fi
    download_op_exec "$install_version"
  fi
}

# --- Main ---

do_install() {
  # Install op CLI
  local op_bin
  op_bin="$(resolve_op_bin)" || true

  # Install op-exec
  local op_exec_bin
  op_exec_bin="$(resolve_op_exec_bin)" || true

  # Verify op is available
  if [ -n "${op_bin:-}" ] && [ -x "${op_bin:-}" ]; then
    echo "${PLUGIN_NAME}: op available at $op_bin" >&2
  fi

  if [ -n "${op_exec_bin:-}" ] && [ -x "${op_exec_bin:-}" ]; then
    echo "${PLUGIN_NAME}: op-exec available at $op_exec_bin" >&2
  fi
}

# --- Execute ---

tool_run_install do_install
echo '{}'
