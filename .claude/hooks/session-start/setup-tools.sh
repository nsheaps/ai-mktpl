#!/usr/bin/env bash
# setup-tools.sh — Project-level SessionStart hook
#
# Ensures critical development tools are available on session start/resume.
# This is a fallback for web sessions where plugin hooks may not fire reliably
# on resume (e.g., after container reset). Since mise.toml defines all needed
# tools (gh, jq, node, bun, etc.), we only need to ensure mise itself works.
#
# On local sessions, this is a no-op.
set -euo pipefail

# Only run in web sessions
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LOCAL_BIN="$PROJECT_DIR/bin/.local"

# --- Ensure bin/.local is on PATH ---
ensure_path() {
  local dir="$1"
  if [ -d "$dir" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    case ":$PATH:" in
      *":$dir:"*) ;;
      *) echo "export PATH=\"$dir:\$PATH\"" >> "$CLAUDE_ENV_FILE"
         export PATH="$dir:$PATH" ;;
    esac
  fi
}

# --- Install mise if missing ---
install_mise() {
  local mise_bin="$LOCAL_BIN/mise"

  # Already available?
  if command -v mise &>/dev/null; then
    echo "setup-tools: mise already on PATH" >&2
    return 0
  fi

  if [ -x "$mise_bin" ]; then
    echo "setup-tools: mise found at $mise_bin, adding to PATH" >&2
    ensure_path "$LOCAL_BIN"
    return 0
  fi

  # Need to install
  echo "setup-tools: Installing mise to $LOCAL_BIN" >&2
  mkdir -p "$LOCAL_BIN"

  # Try to get latest version
  local version=""
  version="$(curl -fsSL "https://api.github.com/repos/jdx/mise/releases/latest" 2>/dev/null \
    | grep '"tag_name"' \
    | sed 's/.*"v\{0,1\}\([^"]*\)".*/\1/' || true)"
  [ -z "$version" ] && version="2024.12.16"

  local url="https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-linux-x64"
  if curl -fsSL "$url" -o "$mise_bin" 2>/dev/null; then
    chmod +x "$mise_bin"
    echo "setup-tools: mise v${version} installed" >&2
  else
    echo "setup-tools: Failed to install mise (network issue?)" >&2
    return 1
  fi

  ensure_path "$LOCAL_BIN"
}

# --- Activate mise and install tools ---
activate_mise() {
  local mise_bin
  mise_bin="$(command -v mise 2>/dev/null || echo "$LOCAL_BIN/mise")"

  if [ ! -x "$mise_bin" ]; then
    echo "setup-tools: mise not available, skipping activation" >&2
    return 1
  fi

  # Persist activation
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "eval \"\$(${mise_bin} activate bash)\"" >> "$CLAUDE_ENV_FILE"
    echo "setup-tools: Persisted mise activation to CLAUDE_ENV_FILE" >&2
  fi

  # Trust and install tools
  if [ -f "$PROJECT_DIR/mise.toml" ]; then
    "$mise_bin" trust "$PROJECT_DIR" 2>/dev/null || true
    echo "setup-tools: Running mise install..." >&2
    (cd "$PROJECT_DIR" && GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" "$mise_bin" install -y 2>&1) \
      || echo "setup-tools: mise install had warnings" >&2
  fi
}

# --- Main ---
install_mise
activate_mise
echo "setup-tools: Done" >&2
