#!/usr/bin/env bash
# install-gh.sh — SessionStart hook for github plugin
#
# Installs or updates GitHub CLI (gh), then runs auth check.
# When installToProject is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="github"


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
      echo "[github] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
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
# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }
# NOTE: No early exit when gh is on PATH — auth check and version=latest
# self-update must still run.  resolve_gh_bin() skips the download internally.

# --- Read config ---

version="$(plugin_get_config "version" "latest")"
auto_install="$(plugin_get_config "autoInstall" "true")"
auto_auth_check="$(plugin_get_config "autoAuthCheck" "true")"

tool_resolve_install_dir

# --- Download helper ---

# Downloads gh at the given version to $INSTALL_DIR, adds to PATH.
# Prints the binary path to stdout. Returns 1 on failure.
download_gh() {
  hook_log_step "download-gh" "Downloading GitHub CLI"
  local target_version="$1"
  local gh_bin="$INSTALL_DIR/gh"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local archive="gh_${target_version}_linux_amd64.tar.gz"
  local url="https://github.com/cli/cli/releases/download/v${target_version}/${archive}"

  hook_log "Downloading gh v${target_version} from ${url}"

  if curl -fsSL "$url" -o "$tmp_dir/$archive" 2>/dev/null; then
    tar -xf "$tmp_dir/$archive" -C "$tmp_dir"
    cp "$tmp_dir/gh_${target_version}_linux_amd64/bin/gh" "$gh_bin"
    chmod +x "$gh_bin"
    rm -rf "$tmp_dir"
    hook_log "gh v${target_version} installed successfully to ${gh_bin}"
    tool_ensure_path "$INSTALL_DIR"
    echo "$gh_bin"
  else
    rm -rf "$tmp_dir"
    hook_fail "gh download" "Failed to download gh v${target_version} from ${url}" \
      "Check network connectivity, or set version to a specific version in plugin settings"
    return 1
  fi
}

# --- Resolve gh binary ---

# Prints the path to a usable gh binary, or returns 1 if unavailable.
resolve_gh_bin() {
  hook_log_step "resolve-gh" "Resolving GitHub CLI binary"
  if [ "$auto_install" = "false" ]; then
    if tool_is_available gh; then
      hook_log "autoInstall=false, using gh from PATH"
      command -v gh
    else
      hook_log "autoInstall=false and gh not on PATH, skipping"
      return 1
    fi
    return
  fi

  local gh_bin="$INSTALL_DIR/gh"

  if [ -x "$gh_bin" ]; then
    # Always ensure PATH includes INSTALL_DIR (critical for session resume)
    tool_ensure_path "$INSTALL_DIR"
    # Already installed — check for updates if version=latest
    if [ "$version" = "latest" ]; then
      local current_version latest_version
      current_version="$("$gh_bin" version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")"
      latest_version="$(tool_resolve_github_version "cli/cli" "2.87.3")"
      if [ "$current_version" = "$latest_version" ]; then
        hook_log "gh $current_version is already latest"
        echo "$gh_bin"
      else
        hook_log "Updating gh from $current_version to $latest_version"
        download_gh "$latest_version"
      fi
    else
      echo "$gh_bin"
    fi
  elif tool_is_available gh; then
    hook_log "gh found on PATH ($(command -v gh)), skipping install"
    command -v gh
  else
    hook_log "Installing gh to $INSTALL_DIR"
    local install_version="$version"
    if [ "$install_version" = "latest" ]; then
      install_version="$(tool_resolve_github_version "cli/cli" "2.87.3")"
    fi
    download_gh "$install_version"
  fi
}

# --- Main ---

do_install() {
  local gh_bin
  gh_bin="$(resolve_gh_bin)" || { hook_respond; exit 0; }

  if [ "$auto_auth_check" = "true" ]; then
    hook_log_step "auth-check" "Checking GitHub CLI authentication"
    "$gh_bin" auth status 2>&1 || hook_log "gh auth not configured"
  fi

  # --- Set GH_HOST and GH_REPO so regular gh subcommands work in web sessions ---
  # In web sessions the git remote is a local proxy, so gh can't infer the
  # GitHub host or repo from it. Exporting these env vars fixes that.
  #
  # Gated to web sessions (CLAUDE_CODE_REMOTE) on purpose: in a local session
  # gh infers host/repo from the cwd's real remote, and setting GH_REPO there
  # would override that for the whole session (e.g. after cd'ing elsewhere).
  # See: https://cli.github.com/manual/gh_help_environment
  if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    return 0
  fi

  hook_log_step "env-vars" "Configuring GH_HOST and GH_REPO for web session"

  if [ -z "${GH_HOST:-}" ]; then
    export GH_HOST="github.com"
    if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
      env_file_upsert_export "$CLAUDE_ENV_FILE" "GH_HOST" "github.com"
    fi
    hook_log "Set GH_HOST=github.com"
  fi

  if [ -z "${GH_REPO:-}" ]; then
    # Infer owner/repo from the git remote URL. Strip a trailing ".git" first,
    # then extract the trailing "owner/repo" segment. (sed -E is POSIX ERE and
    # has no non-greedy quantifier, so it can't strip the suffix in one pass.)
    # Real web-session remote looks like:
    #   http://local_proxy@127.0.0.1:<port>/git/nsheaps/ai-mktpl
    local repo_slug=""
    repo_slug="$(git remote get-url origin 2>/dev/null \
      | sed -E -e 's#\.git$##' -e 's#.*[:/]([^/]+/[^/]+)$#\1#' 2>/dev/null || true)"
    # sed echoes its input unchanged when nothing matches, so a URL with no
    # "owner/repo" path segment would otherwise be exported verbatim — pinning
    # gh to a bogus repo (worse than unset). Require a clean owner/repo shape.
    if printf '%s' "$repo_slug" | grep -qE '^[^/]+/[^/]+$'; then
      export GH_REPO="$repo_slug"
      if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
        env_file_upsert_export "$CLAUDE_ENV_FILE" "GH_REPO" "$repo_slug"
      fi
      hook_log "Set GH_REPO=$repo_slug"
    else
      hook_log "Could not infer GH_REPO from git remote"
    fi
  fi
}

# --- Execute ---

tool_run_install do_install
hook_log_cleanup
hook_respond
