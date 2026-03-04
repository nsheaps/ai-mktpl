#!/usr/bin/env bash
# install-mise.sh — SessionStart hook for mise-tool plugin
#
# Installs or updates mise (tool version manager) for Claude Code web sessions.
# When install_to_project is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
#
# Config resolution order:
#   1. Project-level: ${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml → mise-tool
#   2. User-level:    ~/.claude/plugins.settings.yaml → mise-tool
#   3. Plugin-level:  ${CLAUDE_PLUGIN_ROOT}/mise-tool.settings.yaml → mise-tool
set -euo pipefail

# --- Config reading ---

read_config_key() {
  local file="$1" key="$2"
  if [ -f "$file" ]; then
    if command -v yq &>/dev/null; then
      local val
      val="$(yq -r ".mise-tool.${key}" "$file" 2>/dev/null || true)"
      if [ -n "$val" ] && [ "$val" != "null" ]; then
        echo "$val"
        return 0
      fi
    else
      # Fallback: grep for simple key: value
      local val
      val="$(grep -A1 "mise-tool:" "$file" 2>/dev/null | grep -E "^\s+${key}:" | sed "s/.*${key}:\s*//" | sed 's/^["'\'']//' | sed 's/["'\'']$//' | head -1 || true)"
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

  # 1. Project-level
  if val="$(read_config_key "${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  # 2. User-level
  if val="$(read_config_key "$HOME/.claude/plugins.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  # 3. Plugin-level defaults
  if val="$(read_config_key "${CLAUDE_PLUGIN_ROOT}/mise-tool.settings.yaml" "$key")"; then
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
auto_install_tools="$(get_config "auto_install_tools" "true")"
auto_trust="$(get_config "auto_trust" "true")"

# --- Determine install path ---

if [ "$install_to_project" = "true" ]; then
  INSTALL_DIR="${CLAUDE_PROJECT_DIR:-.}/bin/.local"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

mkdir -p "$INSTALL_DIR"

# --- Install/update function ---

do_install() {
  local mise_bin="$INSTALL_DIR/mise"

  # Check if already installed via this mechanism
  if [ -x "$mise_bin" ]; then
    echo "mise-tool: mise already installed at $mise_bin, checking for updates" >&2
    # Try self-update if version is "latest"
    if [ "$version" = "latest" ]; then
      "$mise_bin" self-update 2>/dev/null || echo "mise-tool: self-update skipped" >&2
    fi
  else
    # Check if mise is available elsewhere on PATH
    if command -v mise &>/dev/null; then
      echo "mise-tool: mise found on PATH ($(command -v mise)), skipping install" >&2
      echo '{}'
      exit 0
    fi

    echo "mise-tool: Installing mise to $INSTALL_DIR" >&2

    if [ "$version" = "latest" ]; then
      # Fetch latest version from GitHub API
      local latest_version
      if command -v gh &>/dev/null; then
        latest_version="$(gh api repos/jdx/mise/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//' || true)"
      fi
      if [ -z "${latest_version:-}" ]; then
        latest_version="$(curl -fsSL https://api.github.com/repos/jdx/mise/releases/latest 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || true)"
      fi
      if [ -z "${latest_version:-}" ]; then
        # Hardcoded fallback
        latest_version="2024.12.16"
        echo "mise-tool: Could not determine latest version, using fallback $latest_version" >&2
      fi
      version="$latest_version"
    fi

    local url="https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-linux-x64"
    if curl -fsSL "$url" -o "$mise_bin" 2>/dev/null; then
      chmod +x "$mise_bin"
      echo "mise-tool: mise v${version} installed successfully" >&2
    else
      echo "mise-tool: Failed to download mise v${version}" >&2
      echo '{}'
      exit 0
    fi
  fi

  # Ensure bin/.local is on PATH via CLAUDE_ENV_FILE
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    if ! echo "$PATH" | tr ':' '\n' | grep -qF "$INSTALL_DIR"; then
      echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
    fi
    # Activate mise
    echo 'eval "$('"$mise_bin"' activate bash)"' >> "$CLAUDE_ENV_FILE"
  fi

  # Export for immediate use in this script
  export PATH="$INSTALL_DIR:$PATH"

  # Auto-trust
  if [ "$auto_trust" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    "$mise_bin" trust "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true
  fi

  # Auto-install tools
  if [ "$auto_install_tools" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    (cd "${CLAUDE_PROJECT_DIR:-.}" && "$mise_bin" install -y 2>&1) || echo "mise-tool: tool installation had warnings" >&2
  fi
}

# --- Execute ---

if [ "$background_install" = "true" ]; then
  do_install &
  echo "mise-tool: Installation running in background" >&2
else
  do_install
fi

echo '{}'
