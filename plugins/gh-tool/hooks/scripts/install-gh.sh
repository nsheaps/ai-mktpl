#!/usr/bin/env bash
# install-gh.sh — SessionStart hook for gh-tool plugin
#
# Installs or updates GitHub CLI (gh) for Claude Code web sessions.
# When install_to_project is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
#
# Config resolution order:
#   1. Project-level: ${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml → gh-tool
#   2. User-level:    ~/.claude/plugins.settings.yaml → gh-tool
#   3. Plugin-level:  ${CLAUDE_PLUGIN_ROOT}/gh-tool.settings.yaml → gh-tool
set -euo pipefail

# --- Config reading ---

read_config_key() {
  local file="$1" key="$2"
  if [ -f "$file" ]; then
    if command -v yq &>/dev/null; then
      local val
      val="$(yq -r ".gh-tool.${key}" "$file" 2>/dev/null || true)"
      if [ -n "$val" ] && [ "$val" != "null" ]; then
        echo "$val"
        return 0
      fi
    else
      local val
      val="$(grep -A1 "gh-tool:" "$file" 2>/dev/null | grep -E "^\s+${key}:" | sed "s/.*${key}:\s*//" | sed 's/^["'\'']//' | sed 's/["'\'']$//' | head -1 || true)"
      if [ -n "$val" ]; then
        echo "$val"
        return 0
      fi
    fi
  fi
  return 1
}

get_config() {
  local key="$1" default="$2"
  local val

  if val="$(read_config_key "${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  if val="$(read_config_key "$HOME/.claude/plugins.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  if val="$(read_config_key "${CLAUDE_PLUGIN_ROOT}/gh-tool.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  echo "$default"
}

# --- Check if enabled ---

enabled="$(get_config "enabled" "true")"
if [ "$enabled" = "false" ]; then
  echo '{}'
  exit 0
fi

# --- Only run on web sessions ---

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  echo '{}'
  exit 0
fi

# --- Read config ---

install_to_project="$(get_config "install_to_project" "true")"
background_install="$(get_config "background_install" "false")"
version="$(get_config "version" "latest")"
auto_auth_check="$(get_config "auto_auth_check" "true")"

# --- Determine install path ---

if [ "$install_to_project" = "true" ]; then
  INSTALL_DIR="${CLAUDE_PROJECT_DIR:-.}/bin/.local"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

mkdir -p "$INSTALL_DIR"

# --- Install/update function ---

do_install() {
  local gh_bin="$INSTALL_DIR/gh"

  # Check if already installed via this mechanism
  if [ -x "$gh_bin" ]; then
    echo "gh-tool: gh already installed at $gh_bin" >&2
    if [ "$version" = "latest" ]; then
      echo "gh-tool: Checking for updates..." >&2
      # gh doesn't have self-update; reinstall if version differs
      local current_version
      current_version="$("$gh_bin" version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")"
      local latest_version
      latest_version="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || true)"
      if [ -n "$latest_version" ] && [ "$current_version" = "$latest_version" ]; then
        echo "gh-tool: gh $current_version is already latest" >&2
        echo '{}'
        exit 0
      fi
      if [ -n "$latest_version" ]; then
        version="$latest_version"
        echo "gh-tool: Updating from $current_version to $latest_version" >&2
      else
        echo '{}'
        exit 0
      fi
    else
      echo '{}'
      exit 0
    fi
  else
    # Check if gh is available elsewhere on PATH
    if command -v gh &>/dev/null; then
      echo "gh-tool: gh found on PATH ($(command -v gh)), skipping install" >&2
      echo '{}'
      exit 0
    fi

    echo "gh-tool: Installing gh to $INSTALL_DIR" >&2

    if [ "$version" = "latest" ]; then
      local latest_version
      latest_version="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || true)"
      if [ -z "$latest_version" ]; then
        latest_version="2.87.3"
        echo "gh-tool: Could not determine latest version, using fallback $latest_version" >&2
      fi
      version="$latest_version"
    fi
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
    echo "gh-tool: gh v${version} installed successfully" >&2
  else
    echo "gh-tool: Failed to download gh v${version}" >&2
    rm -rf "$tmp_dir"
    echo '{}'
    exit 0
  fi
  rm -rf "$tmp_dir"

  # Ensure bin/.local is on PATH via CLAUDE_ENV_FILE
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    if ! echo "$PATH" | tr ':' '\n' | grep -qF "$INSTALL_DIR"; then
      echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
    fi
  fi

  export PATH="$INSTALL_DIR:$PATH"

  # Auth check
  if [ "$auto_auth_check" = "true" ]; then
    "$gh_bin" auth status 2>&1 || echo "gh-tool: gh auth not configured" >&2
  fi
}

# --- Execute ---

if [ "$background_install" = "true" ]; then
  do_install &
  echo "gh-tool: Installation running in background" >&2
else
  do_install
fi

echo '{}'
