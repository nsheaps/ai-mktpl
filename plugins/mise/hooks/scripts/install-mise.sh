#!/usr/bin/env bash
# install-mise.sh — SessionStart hook for mise plugin
#
# Installs or updates mise (tool version manager) for Claude Code web sessions.
# When installToProject is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="mise"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }
tool_is_web_session || { hook_log "not a web session, skipping"; hook_respond; exit 0; }

# --- Read config ---

version="$(plugin_get_config "version" "latest")"
auto_install="$(plugin_get_config "autoInstall" "true")"
auto_install_tools="$(plugin_get_config "autoInstallTools" "true")"
auto_trust="$(plugin_get_config "autoTrust" "true")"

tool_resolve_install_dir

# --- Resolve mise binary ---

resolve_mise_bin() {
  hook_log_step "resolve-mise" "Resolving mise binary"
  local mise_bin="$INSTALL_DIR/mise"

  if [ "$auto_install" = "true" ]; then
    # Check if already installed via this mechanism
    if [ -x "$mise_bin" ]; then
      hook_log "mise already installed at $mise_bin, checking for updates"
      if [ "$version" = "latest" ]; then
        "$mise_bin" self-update -y >/dev/null 2>&1 || hook_log "self-update skipped"
      fi
    elif tool_is_available mise; then
      # Found on PATH from elsewhere — use it
      mise_bin="$(command -v mise)"
      hook_log "mise found on PATH at $mise_bin"
    else
      hook_log "Installing mise to $INSTALL_DIR"
      if [ "$version" = "latest" ]; then
        version="$(tool_resolve_github_version "jdx/mise" "2024.12.16")"
      fi
      local url="https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-linux-x64"
      hook_log "Downloading mise v${version} from ${url}"
      if curl -fsSL "$url" -o "$mise_bin" 2>/dev/null; then
        chmod +x "$mise_bin"
        hook_log "mise v${version} installed successfully"
      else
        hook_fail "mise download" "Failed to download mise v${version} from ${url}" \
          "Check network connectivity, or set version to a specific version in plugin settings"
        return 1
      fi
    fi
    tool_ensure_path "$INSTALL_DIR"
  else
    # autoInstall=false: use whatever mise is on PATH
    if tool_is_available mise; then
      mise_bin="$(command -v mise)"
      hook_log "autoInstall=false, using mise from PATH at $mise_bin"
    else
      hook_log "autoInstall=false and mise not on PATH, skipping"
      return 1
    fi
  fi

  echo "$mise_bin"
}

# --- Main ---

do_setup() {
  local mise_bin
  mise_bin="$(resolve_mise_bin)" || { hook_respond; exit 0; }

  # Activate mise in the current shell AND persist to CLAUDE_ENV_FILE
  hook_log_step "activate-mise" "Activating mise in shell"
  eval "$("$mise_bin" activate bash)" 2>/dev/null || true
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo 'eval "$('"$mise_bin"' activate bash)"' >> "$CLAUDE_ENV_FILE"
    hook_log "Persisted mise activation to CLAUDE_ENV_FILE"
  fi

  # Auto-trust: trust mise config files in project dir and any git worktrees
  if [ "$auto_trust" = "true" ]; then
    local project_dir="${CLAUDE_PROJECT_DIR:-.}"
    local trusted_any=false

    # Trust the primary project dir config
    if [ -f "${project_dir}/mise.toml" ]; then
      hook_log_step "trust-config" "Trusting ${project_dir}/mise.toml"
      "$mise_bin" trust "${project_dir}/mise.toml" || true
      trusted_any=true
    fi

    # Trust mise.toml in any git worktrees
    if command -v git &>/dev/null; then
      while IFS= read -r worktree_dir; do
        if [ "$worktree_dir" != "$project_dir" ] && [ -f "${worktree_dir}/mise.toml" ]; then
          hook_log "Trusting worktree ${worktree_dir}/mise.toml"
          "$mise_bin" trust "${worktree_dir}/mise.toml" || true
          trusted_any=true
        fi
      done < <(git -C "$project_dir" worktree list --porcelain 2>/dev/null | grep "^worktree " | sed 's/^worktree //')
    fi

    if [ "$trusted_any" = "false" ]; then
      hook_log "No mise.toml found to trust"
    fi
  fi

  # Auto-install tools
  if [ "$auto_install_tools" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    hook_log_step "install-tools" "Installing tools from mise.toml"
    local install_output install_rc=0
    install_output="$(cd "${CLAUDE_PROJECT_DIR:-.}" && GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" "$mise_bin" install -y 2>&1)" || install_rc=$?

    if [ "$install_rc" -ne 0 ]; then
      # Check what tools are actually available despite the error
      local available_tools failed_tools
      available_tools=""
      failed_tools=""
      while IFS= read -r tool_line; do
        local tool_name
        tool_name="$(echo "$tool_line" | awk '{print $1}')"
        if [ -n "$tool_name" ] && command -v "$tool_name" &>/dev/null; then
          available_tools="${available_tools:+$available_tools, }$tool_name"
        fi
      done < <(cd "${CLAUDE_PROJECT_DIR:-.}" && "$mise_bin" ls --current 2>/dev/null | tail -n +1 || true)

      # Extract failed tool names from mise output
      if echo "$install_output" | grep -q "Failed to install"; then
        failed_tools="$(echo "$install_output" | grep "Failed to install" | sed 's/.*Failed to install tools: //')"
      fi

      hook_log "mise install completed with warnings (exit code $install_rc)"
      if [ -n "$failed_tools" ]; then
        hook_log "  Partially failed: $failed_tools"
        hook_log "  (tools installed successfully but post-install hooks failed — likely reshim errors)"
      fi

      # Show what's actually available
      local ls_output
      ls_output="$(cd "${CLAUDE_PROJECT_DIR:-.}" && "$mise_bin" ls --current 2>/dev/null || true)"
      if [ -n "$ls_output" ]; then
        hook_log "  Available tools:"
        while IFS= read -r line; do
          [ -n "$line" ] && hook_log "    $line"
        done <<< "$ls_output"
      fi
    fi
  fi
}

# --- Execute ---

tool_run_install do_setup
hook_log_cleanup
hook_respond
