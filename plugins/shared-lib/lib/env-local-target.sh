#!/usr/bin/env bash
# env-local-target.sh — shared helpers for resolving an "envLocal" target
# path (typically $AGENT_HOME_DIR/.env.local) and an optional source-chain
# path to wire from CLAUDE_ENV_FILE.
#
# Originally lived as plugins/1pass/lib/env-local.sh; moved here so it can
# be sourced by multiple plugins without each duplicating the 12-line
# bootstrap stanza. The 1pass plugin's install-op.sh and op-exec-env.sh
# hooks both rely on it.
#
# Dependencies (must be sourced before this file):
#   - plugin-config-read.sh from shared-lib (provides plugin_get_config)
#
# Functions provided:
#   _resolve_env_local_path
#       Echoes the absolute path for the envLocal target on stdout (empty if
#       neither `envLocal.path` config nor AGENT_HOME_DIR/CLAUDE_PROJECT_DIR
#       resolves). Expands $AGENT_HOME_DIR / $CLAUDE_PROJECT_DIR placeholders
#       (both $VAR and ${VAR} forms). Default:
#         $AGENT_HOME_DIR/.env.local
#       Fallback (when AGENT_HOME_DIR is unset):
#         $CLAUDE_PROJECT_DIR/.env.local
#
#   _resolve_env_local_source_chain <envLocalPath>
#       Echoes the path to add as `source <path>` in CLAUDE_ENV_FILE as the
#       SECONDARY chain (alongside the envLocal target itself). NOTE: the
#       envLocal target is ALWAYS chained — `sourceChain: none|false` only
#       opts out of this SECONDARY chain file.
#       Special sentinel values for `envLocal.sourceChain`:
#         "none" or "false" -> echoes empty (no secondary source line added)
#         "self"            -> echoes the envLocal path itself
#       Default (when unset and AGENT_HOME_DIR is set):
#         $AGENT_HOME_DIR/.env
#       Otherwise: empty.
#
#   _chain_env_local_into_claude_env_file <envLocalPath>
#       Chains env_local_path (and its secondary sourceChain, if any) into
#       $CLAUDE_ENV_FILE idempotently. The envLocal target itself is ALWAYS
#       chained because 1pass writes secrets there — `sourceChain: none|false`
#       only opts out of the SECONDARY chain file, not the envLocal target.
#       No-op if env_local_path or CLAUDE_ENV_FILE is empty.
#
# Both `"none"` and `"false"` are accepted as the "disable" sentinel for
# `envLocal.sourceChain`. The two are documented synonyms; `"none"` is the
# preferred form in user-facing docs.

# Guard against double-sourcing
if [ "${_ENV_LOCAL_TARGET_SH_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_ENV_LOCAL_TARGET_SH_LOADED="true"

_resolve_env_local_path() {
  local configured
  configured="$(plugin_get_config "envLocal.path" "")"
  if [ -n "$configured" ]; then
    local expanded="$configured"
    expanded="${expanded//\$AGENT_HOME_DIR/${AGENT_HOME_DIR:-}}"
    expanded="${expanded//\$\{AGENT_HOME_DIR\}/${AGENT_HOME_DIR:-}}"
    expanded="${expanded//\$CLAUDE_PROJECT_DIR/${CLAUDE_PROJECT_DIR:-}}"
    expanded="${expanded//\$\{CLAUDE_PROJECT_DIR\}/${CLAUDE_PROJECT_DIR:-}}"
    echo "$expanded"
    return 0
  fi
  if [ -n "${AGENT_HOME_DIR:-}" ]; then
    echo "${AGENT_HOME_DIR}/.env.local"
  elif [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    echo "${CLAUDE_PROJECT_DIR}/.env.local"
  else
    echo ""
  fi
}

_resolve_env_local_source_chain() {
  local env_local_path="${1:-}"
  local configured
  configured="$(plugin_get_config "envLocal.sourceChain" "")"
  if [ "$configured" = "none" ] || [ "$configured" = "false" ]; then
    echo ""
    return 0
  fi
  if [ "$configured" = "self" ]; then
    echo "$env_local_path"
    return 0
  fi
  if [ -n "$configured" ]; then
    local expanded="$configured"
    expanded="${expanded//\$AGENT_HOME_DIR/${AGENT_HOME_DIR:-}}"
    expanded="${expanded//\$\{AGENT_HOME_DIR\}/${AGENT_HOME_DIR:-}}"
    expanded="${expanded//\$CLAUDE_PROJECT_DIR/${CLAUDE_PROJECT_DIR:-}}"
    expanded="${expanded//\$\{CLAUDE_PROJECT_DIR\}/${CLAUDE_PROJECT_DIR:-}}"
    echo "$expanded"
    return 0
  fi
  if [ -n "${AGENT_HOME_DIR:-}" ]; then
    echo "${AGENT_HOME_DIR}/.env"
  else
    echo ""
  fi
}

# _chain_env_local_into_claude_env_file ENV_LOCAL_PATH
#
# Chains $env_local_path (and its source chain, if any) into $CLAUDE_ENV_FILE
# idempotently. The envLocal target itself is ALWAYS chained because 1pass
# writes secrets there — `sourceChain: none|false` only opts out of the
# SECONDARY chain file, not the envLocal target.
#
# The primary envLocal target is sourced UNGUARDED: 1pass owns that file and
# its absence is a real error worth surfacing.
#
# The SECONDARY chain file (default $AGENT_HOME_DIR/.env) is sourced GUARDED
# via `if [ -r "<path>" ]; then source "<path>"; fi` so that its absence is a
# silent no-op rather than a `zsh:source: no such file or directory` error in
# every shell that loads CLAUDE_ENV_FILE. The secondary chain is an optional
# convenience file — not every agent setup creates one.
#
# Args: $1 = env_local_path (absolute). Reads CLAUDE_ENV_FILE from environment.
# No-op if env_local_path or CLAUDE_ENV_FILE is empty.
_chain_env_local_into_claude_env_file() {
  local env_local_path="$1"
  local chain
  [ -z "$env_local_path" ] && return 0
  [ -z "${CLAUDE_ENV_FILE:-}" ] && return 0
  env_file_upsert_source "$CLAUDE_ENV_FILE" "$env_local_path"
  chain="$(_resolve_env_local_source_chain "$env_local_path")"
  if [ -n "$chain" ] && [ "$chain" != "$env_local_path" ]; then
    env_file_upsert_source_guarded "$CLAUDE_ENV_FILE" "$chain"
  fi
}
