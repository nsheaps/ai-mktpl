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

# --- Result -----------------------------------------------------------------
echo
echo "Result: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
