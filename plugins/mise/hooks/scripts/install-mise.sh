#!/usr/bin/env bash
# install-mise.sh — SessionStart hook for mise plugin
#
# Installs or updates mise (tool version manager), then activates it,
# trusts project configs, and auto-installs tools from mise.toml.
# When installToProject is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="mise"

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
      echo "[$PLUGIN_NAME] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
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
# NOTE: No early exit when mise is on PATH — activation, trust, and tool
# install must still run.  resolve_mise_bin() skips the download internally.

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

  # Re-apply PATH in parent shell (tool_ensure_path ran in subshell above)
  tool_ensure_path "$INSTALL_DIR"

  # Activate mise in the current shell AND persist to CLAUDE_ENV_FILE
  #
  # IMPORTANT: We use `mise env -s bash` instead of `mise activate bash` for
  # CLAUDE_ENV_FILE. `mise activate bash` installs a PROMPT_COMMAND hook that
  # calls `eval "$(mise hook-env -s bash)"` on EVERY bash command. This causes
  # problems because:
  #   1. mise hook-env outputs errors to stderr (and sometimes stdout) when
  #      mise.toml is not trusted, polluting every command's output
  #   2. mise hook-env can output warnings (rate limits, missing tools) to
  #      stdout, which get `eval`'d as bash commands causing "command not found"
  #   3. The activation also overrides cd/pushd/popd to call _mise_hook on
  #      every directory change, compounding the above issues
  #
  # `mise env -s bash` just outputs static `export` statements for the current
  # tool versions — no hooks, no eval loops, no side effects.
  hook_log_step "activate-mise" "Activating mise in shell"
  eval "$("$mise_bin" activate bash)" 2>/dev/null || true
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    # Use `mise env` for persistence — it only exports PATH and tool vars,
    # no hooks or eval loops that run on every command
    echo 'eval "$('"$mise_bin"' env -s bash 2>/dev/null)"' >> "$CLAUDE_ENV_FILE"
    hook_log "Persisted mise env to CLAUDE_ENV_FILE (using mise env, not activate)"
  fi

  # Auto-trust: trust mise config files in project dir and any git worktrees
  if [ "$auto_trust" = "true" ]; then
    local project_dir
    project_dir="$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && pwd)" || project_dir="${CLAUDE_PROJECT_DIR:-.}"
    local trusted_any=false

    # Trust the primary project dir config
    if [ -f "${project_dir}/mise.toml" ]; then
      local trust_path="${project_dir}/mise.toml"
      hook_log_step "trust-config" "Trusting ${trust_path}"
      "$mise_bin" trust "$trust_path" || true
      trusted_any=true
    fi

    # Trust mise.toml in any git worktrees
    if command -v git &>/dev/null; then
      while IFS= read -r worktree_dir; do
        if [ "$worktree_dir" != "$project_dir" ] && [ -f "${worktree_dir}/mise.toml" ]; then
          local wt_trust_path="${worktree_dir}/mise.toml"
          hook_log "Trusting worktree ${wt_trust_path}"
          "$mise_bin" trust "$wt_trust_path" || true
          trusted_any=true
        fi
      done < <(git -C "$project_dir" worktree list --porcelain 2>/dev/null | grep "^worktree " | sed 's/^worktree //')
    fi

    if [ "$trusted_any" = "false" ]; then
      hook_log "No mise.toml found to trust (looked in ${project_dir})"
    fi
  fi

  # Auto-install tools
  if [ "$auto_install_tools" = "true" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/mise.toml" ]; then
    hook_log_step "install-tools" "Installing tools from mise.toml"
    local install_output install_rc=0
    install_output="$(cd "${CLAUDE_PROJECT_DIR:-.}" && GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" "$mise_bin" install -y 2>&1)" || install_rc=$?

    if [ "$install_rc" -ne 0 ]; then
      hook_log "mise install exited non-zero (partial failure). Tools that installed are still available."
      hook_log "mise install output:"
      while IFS= read -r line; do
        [ -n "$line" ] && hook_log "  $line"
      done <<< "$install_output"
    fi
  fi
}

# --- Execute ---

tool_run_install do_setup
hook_log_cleanup
hook_respond
