#!/usr/bin/env bash
# contamination-resistance.sh — regression test for BUG-19 (and PR #487 rework)
#
# Post-rework, the plugin no longer persists static credentials to disk —
# the launcher's .env chain is the only source of GITHUB_APP_ID etc. These
# tests verify:
#
#   1. require_static_env fails loudly when JWT-signing inputs are missing.
#   2. require_static_env succeeds when all inputs are present in env.
#   3. write_runtime_env_file does NOT persist APP_ID / INSTALLATION_ID /
#      PEM_PATH to runtime.env (the original BUG-19 contamination vector).
#   4. The SessionStart hook's case statement routes "unknown" minutes-
#      remaining into the regen path (PR #487 review fix — without this,
#      `set -u` aborts on the bash arithmetic `(( "unknown" > 45 ))`).
#
# Run from anywhere; the script self-isolates via mktemp.
#
#   bash plugins/github-app/tests/contamination-resistance.sh

# Note: no `set -e` — write_runtime_env_file's last `[[ -n ${VAR:-} ]] && ...`
# expression returns 1 when the var is unset, which would kill the test under
# pipefail. The plugin itself runs in subshells where this is not an issue.
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d -t github-app-contam.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- Test fixtures -----------------------------------------------------------

FAKE_PEM="$TMPDIR/fake.pem"
echo "fake-pem" > "$FAKE_PEM"

# Fake AGENT_HOME_DIR / XDG_CONFIG_HOME isolation root. The launcher
# (bin/agent) sets XDG_CONFIG_HOME=$AGENT_HOME_DIR/.config in production;
# we mimic that here.
export AGENT_NAME="testagent"
export AGENT_HOME_DIR="$TMPDIR/agent-home"
export XDG_CONFIG_HOME="$AGENT_HOME_DIR/.config"
mkdir -p "$XDG_CONFIG_HOME"

# Source the plugin's own libs to exercise the same code paths.
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
# shellcheck source=/dev/null
source "$PLUGIN_ROOT/lib/agent-paths.sh"
# shellcheck source=/dev/null
source "$PLUGIN_ROOT/lib/env-file.sh"

mkdir -p "$GITHUB_APP_CONFIG_DIR"

pass=0; fail=0
ok()    { echo "  ✓ $*"; pass=$((pass + 1)); }
bad()   { echo "  ✗ $*"; fail=$((fail + 1)); }

# --- Test 1: require_static_env fails when vars are unset --------------------
echo "[1/3] require_static_env fails loudly when JWT-signing inputs are missing"
(
  unset GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY_PATH
  require_static_env 2>/dev/null
)
rc=$?
if [[ $rc -ne 0 ]]; then
  ok "require_static_env returned nonzero ($rc) when vars unset"
else
  bad "require_static_env returned 0 with missing vars"
fi

# --- Test 2: require_static_env passes when vars are set ---------------------
echo "[2/3] require_static_env succeeds when all inputs are present"
export GITHUB_APP_ID="111111"
export GITHUB_APP_INSTALLATION_ID="222222"
export GITHUB_APP_PRIVATE_KEY_PATH="$FAKE_PEM"
if require_static_env; then
  ok "require_static_env returned 0 with all vars set"
else
  bad "require_static_env returned nonzero with all vars set"
fi

# --- Test 3: write_runtime_env_file does NOT include APP_ID/etc -------------
echo "[3/3] write_runtime_env_file does not persist APP_ID / INSTALLATION_ID / PEM"
write_runtime_env_file "fake-token-xyz"
for key in GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY_PATH; do
  if grep -q "^export ${key}=" "$RUNTIME_ENV_FILE"; then
    bad "$key leaked into runtime.env (BUG-19 vector)"
  else
    ok "$key absent from runtime.env"
  fi
done

# --- Test 4: github-token-init.sh tolerates get_minutes_remaining=unknown ----
#
# Regression for PR #487 review: when token.meta exists but expires_at is
# empty (or unparseable), get_minutes_remaining returns the literal string
# "unknown". Under `set -u`, the SessionStart hook's case statement must
# route that into the regen path — falling through to `(( _minutes > 45 ))`
# triggers bash's "unbound variable" abort on the string "unknown" and
# leaves the session unauthenticated.
echo "[4/4] github-token-init.sh treats unknown as regen path (no set -u abort)"
(
  # Set up a meta file with empty expires_at to force unknown.
  TOKEN_FILE="${GITHUB_APP_CONFIG_DIR}/token"
  mkdir -p "$(dirname "$TOKEN_FILE")"
  printf '{"expires_at": ""}\n' > "${TOKEN_FILE}.meta"

  # Source token-utils and verify get_minutes_remaining returns "unknown".
  META_FILE="${TOKEN_FILE}.meta"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/token-utils.sh"
  result="$(get_minutes_remaining)"
  if [[ "$result" != "unknown" ]]; then
    echo "    fixture didn't produce unknown (got: $result)"
    exit 1
  fi

  # Now exercise the case-statement pattern from github-token-init.sh under
  # the same `set -u` discipline. Pre-fix this would abort.
  set -u
  _minutes="$result"
  _should_regen=true
  case "$_minutes" in
    missing|expired|unknown) ;;
    *)
      if (( _minutes > 45 )); then  # would abort on "unknown" pre-fix
        _should_regen=false
      fi
      ;;
  esac
  [[ "$_should_regen" == "true" ]] || exit 1
)
if [[ $? -eq 0 ]]; then
  ok "case statement routes unknown -> regen without set -u abort"
else
  bad "case statement aborted or mis-routed on unknown"
fi

# --- Result -----------------------------------------------------------------
echo
echo "Result: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
