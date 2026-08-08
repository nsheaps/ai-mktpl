#!/usr/bin/env bash
# direnv-export.sh — Shared helpers for the direnv plugin
#
# Provides the logic that both the SessionStart hook (install-direnv.sh) and
# the PreToolUse hook (direnv-check.sh) need: computing a cheap fingerprint
# of the nearest .envrc, and (re-)running `direnv export bash` to produce a
# STATIC runtime env file.
#
# IMPORTANT — why this is static, not a live eval:
# `direnv export bash` is invoked here exactly once per call to
# direnv_export_and_write(). Its output (plain `export FOO=bar` / `unset BAZ`
# statements) is captured and written verbatim to a runtime file. We do NOT
# wrap it in `eval "$(direnv export bash)"` inside CLAUDE_ENV_FILE, which
# would re-invoke the direnv binary on every single Bash tool call. Instead,
# CLAUDE_ENV_FILE gets one `source <runtime file>` line (added once, idempotently),
# and the runtime file's *contents* are only regenerated when the PreToolUse
# hook (direnv-check.sh) detects the .envrc fingerprint changed. This mirrors
# github-app's env-file.sh pattern (rewrite the runtime file, source it once)
# rather than mise's `eval "$(mise env -s bash)"` pattern (recompute every call).
#
# Requires: hook-logging.sh must be sourced first (for hook_log).
# Note: Plugins symlink this file into their own lib/ directory is NOT used
# here — this file lives directly in plugins/direnv/lib/ since it is not
# shared across plugins.

if [ "${_DIRENV_EXPORT_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_DIRENV_EXPORT_LOADED="true"

# direnv_detect_platform
#
# Sets DIRENV_OS / DIRENV_ARCH globals matching direnv's release asset
# naming: direnv.<os>-<arch> (e.g. direnv.linux-amd64, direnv.darwin-arm64).
# Verified against https://github.com/direnv/direnv/releases (v2.37.1).
# Returns 1 on unsupported platform (after calling hook_fail).
direnv_detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    i386 | i686) arch="386" ;;
    armv*) arch="arm" ;;
    *)
      hook_fail "platform detection" "Unsupported architecture: $arch" \
        "This plugin supports amd64, arm64, arm, and 386 architectures"
      return 1
      ;;
  esac

  case "$os" in
    linux | darwin | freebsd | netbsd | openbsd) ;;
    *)
      hook_fail "platform detection" "Unsupported OS: $os" \
        "direnv publishes releases for linux, darwin, freebsd, netbsd, and openbsd"
      return 1
      ;;
  esac

  DIRENV_OS="$os"
  DIRENV_ARCH="$arch"
}

# direnv_find_nearest_envrc DIR
#
# Walks upward from DIR looking for the nearest .envrc, mirroring direnv's
# own directory-traversal behavior. Stops at filesystem root or after 64
# levels (safety bound). Prints the found path via stdout, or nothing if
# none is found.
direnv_find_nearest_envrc() {
  local dir="$1"
  local i=0
  dir="$(cd "$dir" 2>/dev/null && pwd)" || return 0

  while [ "$i" -lt 64 ]; do
    if [ -f "$dir/.envrc" ]; then
      echo "$dir/.envrc"
      return 0
    fi
    [ "$dir" = "/" ] && return 0
    dir="$(dirname "$dir")"
    i=$((i + 1))
  done
}

# direnv_fingerprint DIR
#
# Computes a cheap fingerprint for the nearest .envrc to DIR: the resolved
# path plus mtime and size. Two fingerprints differ whenever the file is
# added, removed, moved to a different ancestor, or modified. Prints the
# fingerprint via stdout (empty string if no .envrc found anywhere above DIR).
direnv_fingerprint() {
  local dir="$1"
  local envrc
  envrc="$(direnv_find_nearest_envrc "$dir")"

  if [ -z "$envrc" ]; then
    echo "none"
    return 0
  fi

  local stat_out
  if stat_out="$(stat -f '%m:%z' "$envrc" 2>/dev/null)"; then
    : # BSD/macOS stat
  elif stat_out="$(stat -c '%Y:%s' "$envrc" 2>/dev/null)"; then
    : # GNU/Linux stat
  else
    stat_out="unknown"
  fi

  echo "${envrc}:${stat_out}"
}

# direnv_export_and_write DIRENV_BIN TARGET_DIR RUNTIME_FILE
#
# Runs `direnv export bash` from TARGET_DIR and overwrites RUNTIME_FILE with
# the (static) resulting export/unset statements. Always overwrites (never
# appends) so vars removed from .envrc are correctly dropped on the next
# regeneration. Safe to call even when there is no .envrc — direnv exits 0
# with empty output in that case, leaving RUNTIME_FILE with just the header.
#
# Args:
#   $1 — path to the direnv binary
#   $2 — directory to export from (cwd for the `direnv export` call)
#   $3 — path to the runtime env file to (re)write
direnv_export_and_write() {
  local direnv_bin="$1" target_dir="$2" runtime_file="$3"
  local export_output=""
  local rc=0

  mkdir -p "$(dirname "$runtime_file")"

  export_output="$(cd "$target_dir" 2>/dev/null && "$direnv_bin" export bash 2>/dev/null)" || rc=$?
  # direnv exits non-zero when .envrc is blocked/not-allowed/absent in some
  # versions; treat that as "nothing to export" rather than a hard failure —
  # the SessionStart autoAllow step (or the user) is responsible for trust.
  if [ "$rc" -ne 0 ]; then
    export_output=""
  fi

  {
    echo "# Auto-generated by direnv plugin — do not edit manually."
    echo "# Regenerated whenever the .envrc fingerprint changes (see direnv-check.sh)."
    echo "# This is a STATIC snapshot of \`direnv export bash\` output — it is not"
    echo "# re-evaluated on every command. See lib/direnv-export.sh for rationale."
    if [ -n "$export_output" ]; then
      echo "$export_output"
    else
      echo "# (no .envrc found, or .envrc not yet allowed — nothing exported)"
    fi
  } > "$runtime_file"

  chmod 600 "$runtime_file"
}
