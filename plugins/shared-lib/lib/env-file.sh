#!/usr/bin/env bash
# env-file.sh — Idempotent helpers for updating bash-style env files.
#
# Provides upsert/remove operations for two common line types found in env
# files that are sourced by shells (e.g. CLAUDE_ENV_FILE, .env.local):
#
#   export KEY=value
#   source /path/to/file
#
# All operations are idempotent: any pre-existing matching line is removed
# before the new line is appended, so the resulting file has exactly one
# occurrence (for upsert) or zero (for remove) of the targeted line.
#
# Usage:
#   source "/path/to/shared-lib/lib/env-file.sh"
#
#   env_file_upsert_export "$CLAUDE_ENV_FILE" "MY_TOKEN" "$value"
#   env_file_upsert_source "$CLAUDE_ENV_FILE" "$HOME/.env.local"
#   env_file_remove_export "$CLAUDE_ENV_FILE" "MY_TOKEN"
#   env_file_remove_source "$CLAUDE_ENV_FILE" "$HOME/.env.local"
#
# Canonical pattern adapted from plugins/1pass/hooks/scripts/install-op.sh
# (the _write_secret envFile branch).

# Guard against double-sourcing
if [ "${_ENV_FILE_SH_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_ENV_FILE_SH_LOADED="true"

# Internal: ensure file exists (creates parent dir + empty file if missing).
# New files are created at mode 0600 since env files typically hold secrets;
# this is the safe default. Pre-existing files keep their existing perms
# (preserved across upsert/remove via _env_file_replay_perms).
# Args: $1=file_path
_env_file_ensure() {
  local file="$1"
  if [ ! -e "$file" ]; then
    local dir
    dir="$(dirname -- "$file")"
    [ -d "$dir" ] || mkdir -p -- "$dir"
    : > "$file"
    chmod 600 -- "$file" 2>/dev/null || true
  fi
}

# Internal: replay target file's permission bits onto the tmp file before
# the atomic mv. Without this, `mktemp` creates the tmp at 0600 and the
# `mv` keeps the source inode's mode, silently replacing the target's
# previous mode. We copy the target's mode to the tmp so the rename(2)
# preserves the original permissions.
#
# Portable across Linux (GNU coreutils) and macOS (BSD coreutils) by
# using `stat` to read the mode in octal:
#   Linux:  stat -c '%a' <file>
#   macOS:  stat -f '%Mp%Lp' <file>  (file-type bits + permission bits)
# We try the Linux form first, then fall back to BSD.
#
# Args: $1=tmp_path  $2=target_path
_env_file_replay_perms() {
  local tmp="$1" target="$2"
  [ -f "$target" ] || return 0
  local mode=""
  mode="$(stat -c '%a' -- "$target" 2>/dev/null || stat -f '%Mp%Lp' -- "$target" 2>/dev/null || true)"
  if [ -n "$mode" ]; then
    chmod "$mode" -- "$tmp" 2>/dev/null || true
  fi
}

# Internal: strip lines matching an anchored ERE from a file in place,
# via same-directory mktemp+mv (true rename(2) atomic replace). No-op if
# file doesn't exist.
#
# The temp file is created in the SAME DIRECTORY as the target file
# (via `mktemp -- "${file}.XXXXXX"`) so that `mv` is guaranteed to be
# a real rename(2) syscall — atomic on POSIX filesystems. Using a
# default `mktemp` (which lands in $TMPDIR / /tmp) would risk a
# cross-filesystem move that falls back to copy+unlink, which is NOT
# atomic.
#
# Perms preservation: before the mv, the target's current mode is
# replayed onto the tmp file. Otherwise `mv` would silently downgrade
# the target to mktemp's default 0600. If the target doesn't exist
# (first write), the tmp keeps mktemp's 0600 — safe default for env
# files that hold secrets.
# Args: $1=file_path  $2=ERE pattern (passed to grep -E -v)
_env_file_strip_regex() {
  local file="$1" pattern="$2"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  grep -E -v -- "$pattern" "$file" > "$tmp" 2>/dev/null || true
  _env_file_replay_perms "$tmp" "$file"
  mv -- "$tmp" "$file"
}

# Internal: strip lines matching a fixed string (whole-line) from a file
# in place. Used for `source <path>` removal, since paths can contain
# regex metacharacters (dots, plus signs, etc). Same same-directory
# mktemp+mv pattern as _env_file_strip_regex for true rename(2) atomicity
# and perms preservation.
# Args: $1=file_path  $2=fixed_string
_env_file_strip_fixed() {
  local file="$1" needle="$2"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  grep -F -v -x -- "$needle" "$file" > "$tmp" 2>/dev/null || true
  _env_file_replay_perms "$tmp" "$file"
  mv -- "$tmp" "$file"
}

# Idempotently set `export KEY=<quoted-value>` in an env file.
# Removes any prior `export KEY=...` line, then appends the new one.
# Uses printf %q for shell-safe quoting of the value.
# Args: $1=file_path  $2=key  $3=value (may be empty)
env_file_upsert_export() {
  local file="$1" key="$2" value="${3:-}"
  _env_file_ensure "$file"
  _env_file_strip_regex "$file" "^export ${key}="
  printf 'export %s=%q\n' "$key" "$value" >> "$file"
}

# Idempotently set `source <path>` in an env file.
# Removes any prior `source <path>` line, then appends the new one.
# Args: $1=file_path  $2=source_path
env_file_upsert_source() {
  local file="$1" source_path="$2"
  _env_file_ensure "$file"
  _env_file_strip_fixed "$file" "source ${source_path}"
  printf 'source %s\n' "$source_path" >> "$file"
}

# Idempotently set a GUARDED `source <path>` line in an env file:
#
#     if [ -r "<path>" ]; then source "<path>"; fi
#
# The guard makes a missing source file a silent no-op rather than a shell
# error. Use this for OPTIONAL/SECONDARY chain files whose absence should NOT
# break every shell that loads the env file (e.g. $AGENT_HOME_DIR/.env, which
# may or may not exist depending on the agent's setup).
#
# Why `if/then/fi` and not `[ -r ... ] && source ...`:
# Under `set -e`, the `&& source` form returns non-zero as the last command
# of a sourced file when the guard fails, which aborts the sourcing shell.
# The `if/then/fi` form is exit-status-neutral.
#
# Use the unguarded env_file_upsert_source for files whose absence IS a real
# error (e.g. the 1pass-managed .env.local).
#
# Removes any prior guarded source line for the same path, then appends the
# new one. (Does not remove an unguarded `source <path>` line — those are
# managed via env_file_upsert_source / env_file_remove_source.)
# Args: $1=file_path  $2=source_path
env_file_upsert_source_guarded() {
  local file="$1" source_path="$2"
  _env_file_ensure "$file"
  _env_file_strip_fixed "$file" "if [ -r \"${source_path}\" ]; then source \"${source_path}\"; fi"
  printf 'if [ -r "%s" ]; then source "%s"; fi\n' "$source_path" "$source_path" >> "$file"
}

# Idempotently remove any guarded source line for <path>.
# No-op if the file or the line doesn't exist.
# Args: $1=file_path  $2=source_path
env_file_remove_source_guarded() {
  local file="$1" source_path="$2"
  _env_file_strip_fixed "$file" "if [ -r \"${source_path}\" ]; then source \"${source_path}\"; fi"
}

# Idempotently remove any `export KEY=...` line from an env file.
# No-op if the file or the line doesn't exist.
# Args: $1=file_path  $2=key
env_file_remove_export() {
  local file="$1" key="$2"
  _env_file_strip_regex "$file" "^export ${key}="
}

# Idempotently remove any `source <path>` line from an env file.
# No-op if the file or the line doesn't exist.
# Args: $1=file_path  $2=source_path
env_file_remove_source() {
  local file="$1" source_path="$2"
  _env_file_strip_fixed "$file" "source ${source_path}"
}
