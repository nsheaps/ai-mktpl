#!/usr/bin/env bash
# resolve-op-env.sh — Shared helper: resolve a single 1Password item via op-exec
#                     and call a callback for each exported env var.
#
# Requirements (must be set by the caller before sourcing this file):
#   PLUGIN_NAME      — used by hook_log / hook_fail for log prefixes
#   hook_log()       — logging function from shared-lib/hook-logging.sh
#   hook_fail()      — error logging function from shared-lib/hook-logging.sh
#   _OP_EXEC_TMPDIR  — writable tmpdir (caller owns cleanup via EXIT trap)
#
# Exports:
#   op_resolve_item_to_callback ITEM_REF CALLBACK_FN
#     Resolves all env vars from ITEM_REF and calls CALLBACK_FN with each
#     (name, value) pair. The callback signature must be:
#       callback_fn ENV_NAME ENV_VALUE
#     Tracks and logs the count of vars resolved. Returns 0 on all paths;
#     errors are logged via hook_fail, not raised.

# Guard against double-sourcing
[ "${_RESOLVE_OP_ENV_SH_LOADED:-}" = "1" ] && return 0
_RESOLVE_OP_ENV_SH_LOADED=1

# op_resolve_item_to_callback ITEM_REF CALLBACK_FN
#
# Resolves the given op:// item reference via op-exec, evaluates the output in
# an isolated subshell (env -i HOME=$HOME PATH=$PATH bash -c "eval ...; env -0")
# to handle multi-line values and heredoc-style assignments safely, parses the
# NUL-delimited records, skips shell-injected vars (HOME, PATH, PWD, OLDPWD,
# SHLVL, _), and calls CALLBACK_FN for each remaining (name, value) pair.
#
# Uses the same eval pattern as the original op-exec-env.sh::process_item so
# behaviour is byte-identical except for the write step (delegated to callback).
op_resolve_item_to_callback() {
  local item_ref="$1"
  local callback_fn="$2"

  hook_log_step "op-exec" "Resolving item: $item_ref"

  # Validate reference format
  if ! [[ "$item_ref" =~ ^op://[^/]+/[^/]+ ]]; then
    hook_fail "op-exec" "Invalid reference format: $item_ref (expected op://vault/item)" \
      "Check opExec.items in plugin settings"
    return 0
  fi

  # Run op-exec to get export statements.
  # If _OP_EXEC_CONCEALED_KV_FILE is set, pass --concealed-kv-file so op-exec
  # writes CONCEALED `NAME=value` pairs (mode 600) to that file. The flag must
  # come before the op:// reference because op-exec's flag parser stops on op://.
  # Requires op-exec >= 0.1.0.
  local _concealed_args=()
  if [[ -n "${_OP_EXEC_CONCEALED_KV_FILE:-}" ]]; then
    _concealed_args=(--concealed-kv-file "$_OP_EXEC_CONCEALED_KV_FILE")
  fi

  local exports op_exec_stderr
  op_exec_stderr="$(mktemp -p "$_OP_EXEC_TMPDIR")"
  if ! exports="$(op-exec "${_concealed_args[@]}" "$item_ref" 2>"$op_exec_stderr")"; then
    local err_detail=""
    [[ -s "$op_exec_stderr" ]] && err_detail=" — $(cat "$op_exec_stderr")"
    rm -f "$op_exec_stderr"
    hook_fail "op-exec" "Failed to resolve item: $item_ref${err_detail}" \
      "Verify the item exists and op has access to the vault"
    return 0
  fi
  rm -f "$op_exec_stderr"

  if [ -z "$exports" ]; then
    hook_log "no fields found in $item_ref"
    return 0
  fi

  # Evaluate op-exec output in a clean subshell to resolve heredocs/complex
  # syntax. op-exec can output heredoc-style assignments (e.g.
  # export VAR=$(cat <<'EOF'...)) which break line-by-line parsing. By eval'ing
  # in env -i, only exported vars appear in the output. We use `env -0` to
  # NUL-delimit records, which correctly handles multi-line values (e.g. PEM
  # keys). NUL bytes can't appear in env values, so this is the only safe
  # delimiter. We write via process-sub because bash strips NULs from $().
  local eval_stderr eval_output
  eval_stderr="$(mktemp -p "$_OP_EXEC_TMPDIR")"
  eval_output="$(mktemp -p "$_OP_EXEC_TMPDIR")"
  local eval_exit=0
  env -i HOME="$HOME" PATH="$PATH" bash -c "
    set -e
    eval \"\$1\"
    env -0
  " _ "$exports" 2>"$eval_stderr" > "$eval_output" || eval_exit=$?

  if [[ $eval_exit -ne 0 ]]; then
    local err_msg=""
    [[ -s "$eval_stderr" ]] && err_msg="$(cat "$eval_stderr")"
    hook_fail "op-exec" "Failed to evaluate op-exec output for: $item_ref${err_msg:+ — $err_msg}" \
      "The op-exec output may contain syntax that bash cannot evaluate"
    rm -f "$eval_stderr" "$eval_output"
    return 0
  fi

  # Log any stderr even on success (diagnostics, not fatal)
  if [[ -s "$eval_stderr" ]]; then
    while IFS= read -r line; do
      hook_log "[eval stderr] $line"
    done < "$eval_stderr"
  fi
  rm -f "$eval_stderr"

  # Parse NUL-delimited KEY=VALUE records from the isolated subshell.
  local count=0
  while IFS= read -r -d '' record; do
    [ -z "$record" ] && continue
    local env_name="${record%%=*}"
    local env_value="${record#*=}"
    # Skip vars injected for the isolated bash to work (not from op-exec)
    case "$env_name" in
      HOME|PATH|PWD|OLDPWD|SHLVL|_) continue ;;
    esac
    if [ -n "$env_name" ]; then
      "$callback_fn" "$env_name" "$env_value"
      count=$((count + 1))
    fi
  done < "$eval_output"
  rm -f "$eval_output"

  hook_log "resolved $count env vars from $item_ref"
  return 0
}
