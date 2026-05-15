#!/usr/bin/env bash
# env-local-target.test.sh — tests for the 1pass plugin's envLocal target.
#
# Exercises the shared `plugins/shared-lib/lib/env-local-target.sh` helpers used by BOTH
# SessionStart hooks (install-op.sh + op-exec-env.sh), so this test covers
# the envLocal codepath in both entry points.
#
# Validates:
#   - _resolve_env_local_path expands $AGENT_HOME_DIR and falls back as documented
#   - _resolve_env_local_source_chain supports "self" / "none" / "false" / default
#   - env_file_upsert_export writes idempotently to the envLocal path
#   - CLAUDE_ENV_FILE gets a `source` line for the resolved sourceChain
#
# Run from anywhere:
#   bash plugins/1pass/tests/env-local-target.test.sh

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED_LIB_ROOT="$(cd "$PLUGIN_ROOT/../shared-lib" && pwd)"
TMPDIR_TEST="$(mktemp -d -t 1pass-env-local.XXXXXX)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Source shared-lib helpers used by the 1pass scripts.
# shellcheck source=/dev/null
source "$SHARED_LIB_ROOT/lib/env-file.sh"

# Define the stub plugin_get_config that the helpers depend on. We model it
# as a simple associative-array lookup so tests can set per-case values.
declare -A _STUB_CONFIG
plugin_get_config() {
  local key="$1" default="${2:-}"
  local val="${_STUB_CONFIG[$key]:-}"
  if [ -z "$val" ]; then
    echo "$default"
  else
    echo "$val"
  fi
}

# Source the shared envLocal helpers directly. Both install-op.sh and
# op-exec-env.sh source this same file via
# ${SHARED_LIB_DIR}/env-local-target.sh, so exercising it here covers both
# SessionStart hook codepaths.
# shellcheck source=/dev/null
source "$SHARED_LIB_ROOT/lib/env-local-target.sh"

# Sanity-check that the consumers actually source the shared lib (so this test
# stays meaningful as coverage for both hook entry points).
for consumer in "$PLUGIN_ROOT/hooks/scripts/install-op.sh" \
                "$PLUGIN_ROOT/hooks/scripts/op-exec-env.sh"; do
  if ! grep -q 'env-local-target.sh' "$consumer"; then
    echo "FAIL: $consumer no longer sources env-local-target.sh — test coverage assumption invalid" >&2
    exit 1
  fi
done

pass=0; fail=0
ok()  { echo "  ✓ $*"; pass=$((pass + 1)); }
bad() { echo "  ✗ $*"; fail=$((fail + 1)); }

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [ "$got" = "$want" ]; then ok "$desc"
  else bad "$desc (got=$got want=$want)"
  fi
}

# --- Test 1: path resolution defaults to $AGENT_HOME_DIR/.env.local --------
echo "Test 1: _resolve_env_local_path default (AGENT_HOME_DIR set)"
_STUB_CONFIG=()
AGENT_HOME_DIR="$TMPDIR_TEST/agent-home" CLAUDE_PROJECT_DIR="$TMPDIR_TEST/proj" \
  assert_eq "$(AGENT_HOME_DIR=$TMPDIR_TEST/agent-home CLAUDE_PROJECT_DIR=$TMPDIR_TEST/proj _resolve_env_local_path)" \
            "$TMPDIR_TEST/agent-home/.env.local" \
            "defaults to AGENT_HOME_DIR/.env.local"

# --- Test 2: falls back to $CLAUDE_PROJECT_DIR/.env.local ------------------
echo "Test 2: _resolve_env_local_path fallback to CLAUDE_PROJECT_DIR"
assert_eq "$(unset AGENT_HOME_DIR; CLAUDE_PROJECT_DIR=$TMPDIR_TEST/proj _resolve_env_local_path)" \
          "$TMPDIR_TEST/proj/.env.local" \
          "falls back to CLAUDE_PROJECT_DIR/.env.local"

# --- Test 3: empty when neither is set -------------------------------------
echo "Test 3: _resolve_env_local_path empty when no env vars"
assert_eq "$(unset AGENT_HOME_DIR CLAUDE_PROJECT_DIR; _resolve_env_local_path)" \
          "" \
          "empty when AGENT_HOME_DIR and CLAUDE_PROJECT_DIR unset"

# --- Test 4: configured path with $AGENT_HOME_DIR placeholder --------------
echo "Test 4: _resolve_env_local_path expands placeholders"
_STUB_CONFIG["envLocal.path"]='$AGENT_HOME_DIR/custom/.env.local'
assert_eq "$(AGENT_HOME_DIR=$TMPDIR_TEST/h _resolve_env_local_path)" \
          "$TMPDIR_TEST/h/custom/.env.local" \
          "expands \$AGENT_HOME_DIR in configured path"
_STUB_CONFIG=()

# --- Test 5: sourceChain default ($AGENT_HOME_DIR/.env) --------------------
echo "Test 5: _resolve_env_local_source_chain default"
assert_eq "$(AGENT_HOME_DIR=$TMPDIR_TEST/h _resolve_env_local_source_chain "$TMPDIR_TEST/h/.env.local")" \
          "$TMPDIR_TEST/h/.env" \
          "defaults to AGENT_HOME_DIR/.env"

# --- Test 6: sourceChain "self" returns envLocal path ----------------------
echo "Test 6: _resolve_env_local_source_chain self"
_STUB_CONFIG["envLocal.sourceChain"]="self"
assert_eq "$(_resolve_env_local_source_chain "/tmp/foo/.env.local")" \
          "/tmp/foo/.env.local" \
          "self returns envLocal path"
_STUB_CONFIG=()

# --- Test 7: sourceChain "none" returns empty ------------------------------
echo "Test 7: _resolve_env_local_source_chain none"
_STUB_CONFIG["envLocal.sourceChain"]="none"
assert_eq "$(AGENT_HOME_DIR=$TMPDIR_TEST/h _resolve_env_local_source_chain "/tmp/x")" \
          "" \
          "none returns empty"
_STUB_CONFIG=()

# --- Test 7b: sourceChain "false" alias also returns empty -----------------
echo "Test 7b: _resolve_env_local_source_chain false (alias for none)"
_STUB_CONFIG["envLocal.sourceChain"]="false"
assert_eq "$(AGENT_HOME_DIR=$TMPDIR_TEST/h _resolve_env_local_source_chain "/tmp/x")" \
          "" \
          "false alias returns empty"
_STUB_CONFIG=()

# --- Test 8: end-to-end — upsert + source chain idempotence ----------------
echo "Test 8: end-to-end upsert + source chain"
env_local="$TMPDIR_TEST/agent-home/.env.local"
claude_env="$TMPDIR_TEST/claude-env-file"
source_chain="$TMPDIR_TEST/agent-home/.env"

# Run twice with same input; expect single export and single source line.
for _ in 1 2; do
  env_file_upsert_export "$env_local" "GITHUB_APP_ID" "12345"
  env_file_upsert_export "$env_local" "GITHUB_APP_ID" "12345"  # second time same val
  env_file_upsert_source "$claude_env" "$source_chain"
done

if [ "$(grep -c '^export GITHUB_APP_ID=' "$env_local")" = "1" ]; then
  ok "envLocal has exactly one export line after repeated upserts"
else
  bad "envLocal has duplicate export lines"
  sed 's/^/    /' "$env_local" >&2
fi

if [ "$(grep -F -x -c "source $source_chain" "$claude_env")" = "1" ]; then
  ok "CLAUDE_ENV_FILE has exactly one source line after repeated upserts"
else
  bad "CLAUDE_ENV_FILE has duplicate source lines"
  sed 's/^/    /' "$claude_env" >&2
fi

# --- Test 9: value change replaces, doesn't append ------------------------
echo "Test 9: changing value replaces in-place"
env_file_upsert_export "$env_local" "GITHUB_APP_ID" "99999"
got_val="$(grep '^export GITHUB_APP_ID=' "$env_local" | tail -1)"
if [ "$(grep -c '^export GITHUB_APP_ID=' "$env_local")" = "1" ] && \
   [[ "$got_val" == *"99999"* ]]; then
  ok "value change replaces in-place, no duplicates"
else
  bad "value change produced duplicate or wrong line ($got_val)"
fi

# --- Test 10: install-op.sh _write_secret envLocal skip-when-unresolvable -
# When _resolve_env_local_path returns empty (no envLocal.path, no
# AGENT_HOME_DIR, no CLAUDE_PROJECT_DIR), the install-op.sh _write_secret
# envLocal branch must skip the secret (return 0 + hook_log) rather than
# failing the hook. This mirrors op-exec-env.sh:126-128 behavior. Verified
# by simulating the resolve+skip sequence the way _write_secret does it.
echo "Test 10: install-op.sh skip-when-envLocal-unresolvable mirrors op-exec-env.sh"
_STUB_CONFIG=()
# Unset BOTH env vars so resolver returns empty.
unresolved_path="$(unset AGENT_HOME_DIR CLAUDE_PROJECT_DIR; _resolve_env_local_path)"
if [ -z "$unresolved_path" ]; then
  ok "resolver returns empty when AGENT_HOME_DIR + CLAUDE_PROJECT_DIR unset"
else
  bad "resolver unexpectedly returned: $unresolved_path"
fi

# Verify the install-op.sh source actually uses the skip-not-fail pattern.
# This is a coverage/grep check — it ensures the code keeps the new behavior.
if grep -q 'envLocal target not resolvable, skipping' "$PLUGIN_ROOT/hooks/scripts/install-op.sh"; then
  ok "install-op.sh uses skip log message (matches op-exec-env.sh pattern)"
else
  bad "install-op.sh missing skip log — has the skip-not-fail pattern regressed?"
fi
if grep -A2 'envLocal target not resolvable, skipping' "$PLUGIN_ROOT/hooks/scripts/install-op.sh" | grep -q 'return 0'; then
  ok "install-op.sh returns 0 (skip) instead of return 1 (fail)"
else
  bad "install-op.sh still uses 'return 1' on envLocal unresolvable — should be 'return 0'"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
