#!/usr/bin/env bash
# install-direnv.sh — SessionStart hook for direnv plugin
#
# Installs/updates direnv, then computes the .envrc env diff ONCE via
# `direnv export bash` and writes it as STATIC export statements to a
# runtime env file that is sourced via CLAUDE_ENV_FILE.
#
# IMPORTANT: We deliberately do NOT install `direnv hook bash` (the
# PROMPT_COMMAND-style shell hook). That hook re-invokes
# `direnv export bash` via `eval` on every single shell prompt, which causes
# the same class of problems documented at length in mise's install-mise.sh:
#   1. direnv can write status/error output (e.g. "direnv: loading .envrc")
#      to stderr on every command, and some versions/configs leak text to
#      stdout too — polluting command output.
#   2. Any stray stdout from the hook gets `eval`'d as bash, which is an
#      eval-injection risk if an .envrc (or a bug in direnv) ever emits
#      unexpected text.
#   3. The hook overrides cd/pushd/popd to re-run on every directory change,
#      which is unnecessary overhead in a non-interactive agent shell.
#
# Instead: `direnv export bash` is run exactly once here (at session start),
# and again only when the PreToolUse hook (direnv-check.sh) detects the
# .envrc fingerprint has changed. See lib/direnv-export.sh for the shared
# implementation and further rationale.
#
# Install mechanism: prefers claude-utils' `agent-plugin ensure-dependency`
# (mise-based) when `agent-plugin` is on PATH, falling back to a direct
# GitHub-release download otherwise. Logging: prefers `agent-plugin log-*`
# when present, always also uses this repo's shared-lib hook-logging.sh
# lifecycle (hook_log_step/hook_fail/hook_respond). See lib/direnv-export.sh
# for why both are treated as present-if-available rather than hard
# dependencies.
set -euo pipefail

PLUGIN_NAME="direnv"

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
_wait_for_shared_lib "env-file.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/tool-install.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/env-file.sh"

# --- Plugin-local lib (fingerprint + export helpers shared with PreToolUse hook) ---
# shellcheck source=../../lib/direnv-export.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/direnv-export.sh"

# --- Guards ---

plugin_is_enabled || { direnv_log "info" "plugin disabled, skipping"; hook_respond; exit 0; }

# --- Read config ---

version="$(plugin_get_config "version" "latest")"
auto_install="$(plugin_get_config "autoInstall" "true")"
auto_allow="$(plugin_get_config "autoAllow" "true")"

tool_resolve_install_dir

# --- Resolve direnv binary ---

resolve_direnv_bin() {
  hook_log_step "resolve-direnv" "Resolving direnv binary"
  local direnv_bin="$INSTALL_DIR/direnv"

  if [ "$auto_install" != "true" ]; then
    if tool_is_available direnv; then
      direnv_log "info" "autoInstall=false, using direnv from PATH at $(command -v direnv)"
      command -v direnv
      return 0
    fi
    direnv_log "info" "autoInstall=false and direnv not on PATH, skipping"
    return 1
  fi

  if [ -x "$direnv_bin" ]; then
    direnv_log "info" "direnv already installed at $direnv_bin"
    echo "$direnv_bin"
    return 0
  fi

  if tool_is_available direnv; then
    direnv_bin="$(command -v direnv)"
    direnv_log "info" "direnv found on PATH at $direnv_bin"
    echo "$direnv_bin"
    return 0
  fi

  # --- Preferred path: claude-utils' agent-plugin, if present ---
  #
  # Enhancement, not a hard dependency (see lib/direnv-export.sh header for
  # why): tries `agent-plugin ensure-dependency direnv "direnv@latest"`
  # (installs via `mise use -g`) when `agent-plugin` is on PATH. Falls
  # through to the direct GitHub-release download below on ANY failure —
  # agent-plugin not installed, its own autoInstall setting declining, no
  # mise, or the mise install itself failing — so this plugin keeps working
  # exactly as before for the 100% of users who haven't installed
  # claude-utils or configured .claude/settings.direnv.yaml.
  if [ -n "$(direnv_agent_plugin_bin)" ]; then
    local via_agent_plugin
    if via_agent_plugin="$(direnv_try_ensure_dependency_via_agent_plugin)" && [ -n "$via_agent_plugin" ]; then
      direnv_log "info" "direnv resolved via agent-plugin/mise at ${via_agent_plugin}"
      echo "$via_agent_plugin"
      return 0
    fi
    direnv_log "info" "agent-plugin present but did not provide direnv (declined, no mise, or install failed) — falling back to direct download"
  fi

  # --- Fallback: direct GitHub release download (unchanged from before the
  # agent-plugin integration; this is the only path when claude-utils isn't
  # installed, which is every session today) ---

  direnv_detect_platform || return 1

  local target_version="$version"
  if [ "$target_version" = "latest" ]; then
    target_version="$(tool_resolve_github_version "direnv/direnv" "2.37.1")"
  fi

  # Asset naming verified against a live GitHub release (v2.37.1): direnv
  # publishes a bare, unversioned executable per platform — no "v" prefix,
  # no archive. e.g. direnv.linux-amd64, direnv.darwin-arm64.
  local asset="direnv.${DIRENV_OS}-${DIRENV_ARCH}"
  local url="https://github.com/direnv/direnv/releases/download/v${target_version}/${asset}"

  hook_log_step "download-direnv" "Downloading direnv v${target_version} from ${url}"
  if curl -fsSL "$url" -o "$direnv_bin" 2>/dev/null; then
    chmod +x "$direnv_bin"
    direnv_log "info" "direnv v${target_version} installed to ${direnv_bin}"
    echo "$direnv_bin"
    return 0
  fi

  hook_fail "direnv download" "Failed to download direnv v${target_version} from ${url}" \
    "Check network connectivity, or set version to a specific release in plugin settings"
  return 1
}

# --- Auto-allow: trust .envrc in project dir and any git worktrees ---
#
# direnv refuses to load an .envrc it hasn't seen `direnv allow`ed (a
# security feature, mirroring mise's `mise trust`). Without this, the export
# step below silently produces nothing for a fresh/unapproved .envrc.
auto_allow_envrc() {
  local direnv_bin="$1"
  [ "$auto_allow" = "true" ] || { direnv_log "info" "autoAllow=false, skipping direnv allow"; return 0; }

  local project_dir
  project_dir="$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && pwd)" || project_dir="${CLAUDE_PROJECT_DIR:-.}"
  local allowed_any=false

  if [ -f "${project_dir}/.envrc" ]; then
    hook_log_step "allow-envrc" "Allowing ${project_dir}/.envrc"
    "$direnv_bin" allow "${project_dir}/.envrc" || true
    allowed_any=true
  fi

  if command -v git &>/dev/null; then
    while IFS= read -r worktree_dir; do
      if [ "$worktree_dir" != "$project_dir" ] && [ -f "${worktree_dir}/.envrc" ]; then
        direnv_log "info" "Allowing worktree ${worktree_dir}/.envrc"
        "$direnv_bin" allow "${worktree_dir}/.envrc" || true
        allowed_any=true
      fi
    done < <(git -C "$project_dir" worktree list --porcelain 2>/dev/null | grep "^worktree " | sed 's/^worktree //')
  fi

  if [ "$allowed_any" = "false" ]; then
    direnv_log "info" "No .envrc found to allow (looked in ${project_dir})"
  fi
}

# --- Main ---

do_setup() {
  local direnv_bin
  direnv_bin="$(resolve_direnv_bin)" || { hook_respond; exit 0; }

  tool_ensure_path "$INSTALL_DIR"

  auto_allow_envrc "$direnv_bin"

  local project_dir="${CLAUDE_PROJECT_DIR:-.}"
  local runtime_file="${CLAUDE_PLUGIN_DATA}/direnv-env"
  local fingerprint_file="${CLAUDE_PLUGIN_DATA}/direnv-fingerprint"

  hook_log_step "export-envrc" "Computing .envrc diff via 'direnv export bash'"
  direnv_export_and_write "$direnv_bin" "$project_dir" "$runtime_file"
  direnv_fingerprint "$project_dir" > "$fingerprint_file"

  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    env_file_upsert_source "$CLAUDE_ENV_FILE" "$runtime_file"
    direnv_log "info" "Wired ${runtime_file} into CLAUDE_ENV_FILE (static snapshot, not a live shell hook)"
  fi

  local direnv_ver
  direnv_ver="$("$direnv_bin" --version 2>/dev/null || echo "unknown")"
  direnv_log "info" "direnv v${direnv_ver} available at ${direnv_bin}"
}

# --- Execute ---

tool_run_install do_setup
hook_log_cleanup
hook_respond
