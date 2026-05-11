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
# Args: $1=file_path
_env_file_ensure() {
  local file="$1"
  if [ ! -e "$file" ]; then
    local dir
    dir="$(dirname -- "$file")"
    [ -d "$dir" ] || mkdir -p -- "$dir"
    : > "$file"
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
# Args: $1=file_path  $2=ERE pattern (passed to grep -E -v)
_env_file_strip_regex() {
  local file="$1" pattern="$2"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  grep -E -v -- "$pattern" "$file" > "$tmp" 2>/dev/null || true
  mv -- "$tmp" "$file"
}

# Internal: strip lines matching a fixed string (whole-line) from a file
# in place. Used for `source <path>` removal, since paths can contain
# regex metacharacters (dots, plus signs, etc). Same same-directory
# mktemp+mv pattern as _env_file_strip_regex for true rename(2) atomicity.
# Args: $1=file_path  $2=fixed_string
_env_file_strip_fixed() {
  local file="$1" needle="$2"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(mktemp -- "${file}.XXXXXX")"
  grep -F -v -x -- "$needle" "$file" > "$tmp" 2>/dev/null || true
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
