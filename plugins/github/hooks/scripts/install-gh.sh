#!/usr/bin/env bash
# install-gh.sh — SessionStart hook for github plugin
#
# Installs or updates GitHub CLI (gh) for Claude Code web sessions.
# When installToProject is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="github"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }
tool_is_web_session || { hook_log "not a web session, skipping"; hook_respond; exit 0; }

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
  # GitHub host or repo.  Setting these env vars fixes that globally.
  # See: https://cli.github.com/manual/gh_help_environment
  hook_log_step "env-vars" "Configuring GH_HOST and GH_REPO for web session"

  if [ -z "${GH_HOST:-}" ]; then
    export GH_HOST="github.com"
    if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
      echo 'export GH_HOST="github.com"' >> "$CLAUDE_ENV_FILE"
    fi
    hook_log "Set GH_HOST=github.com"
  fi

  if [ -z "${GH_REPO:-}" ]; then
    # Try to infer owner/repo from the git remote URL
    local repo_slug=""
    repo_slug="$(git remote get-url origin 2>/dev/null \
      | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#' 2>/dev/null || true)"
    if [ -n "$repo_slug" ]; then
      export GH_REPO="$repo_slug"
      if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
        echo "export GH_REPO=\"$repo_slug\"" >> "$CLAUDE_ENV_FILE"
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
