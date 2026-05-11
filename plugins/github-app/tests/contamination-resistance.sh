#!/usr/bin/env bash
# contamination-resistance.sh — regression test for BUG-19
#
# Reproduces the scenario where another agent's GitHub App vars are present
# in process env at install/SessionStart time, and proves:
#
#   1. install.sh refuses to silently overwrite static.env from contaminated env
#      (it uses explicit positional args; the contaminated env is irrelevant).
#   2. read_static_env_file() loads from disk and overwrites any contaminated
#      GITHUB_APP_ID / GITHUB_APP_INSTALLATION_ID / GITHUB_APP_PRIVATE_KEY_PATH
#      already in env.
#   3. The runtime path (token-init.sh) NEVER reads APP_ID/INSTALLATION_ID/
#      PEM_PATH from process env. It only consumes static.env.
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

CORRECT_APP_ID="111111"
CORRECT_INSTALLATION_ID="222222"
CORRECT_PEM="$TMPDIR/correct.pem"
echo "fake-pem-correct" > "$CORRECT_PEM"

WRONG_APP_ID="999999"
WRONG_INSTALLATION_ID="888888"
WRONG_PEM="$TMPDIR/wrong.pem"
echo "fake-pem-wrong" > "$WRONG_PEM"

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

# --- Test 1: write_static_env_file ignores process env ----------------------
echo "[1/3] write_static_env_file uses positional args, not process env"
GITHUB_APP_ID="$WRONG_APP_ID" \
GITHUB_APP_INSTALLATION_ID="$WRONG_INSTALLATION_ID" \
GITHUB_APP_PRIVATE_KEY_PATH="$WRONG_PEM" \
write_static_env_file \
  "$CORRECT_APP_ID" "$CORRECT_INSTALLATION_ID" "$CORRECT_PEM" "" "" "test"

if grep -q "GITHUB_APP_ID=\"$CORRECT_APP_ID\"" "$STATIC_ENV_FILE"; then
  ok "static.env contains the CORRECT app id from positional arg"
else
  bad "static.env does NOT contain the correct app id"
fi
if grep -q "GITHUB_APP_ID=\"$WRONG_APP_ID\"" "$STATIC_ENV_FILE"; then
  bad "static.env contains the WRONG app id from contaminated env"
else
  ok "static.env does NOT contain the wrong app id from contaminated env"
fi

# --- Test 2: read_static_env_file overrides contaminated env ----------------
# Run inline (not in subshell) so pass/fail counters propagate. We restore the
# vars by re-sourcing static.env, which is exactly what we're testing anyway.
echo "[2/3] read_static_env_file overwrites contaminated env values"
export GITHUB_APP_ID="$WRONG_APP_ID"
export GITHUB_APP_INSTALLATION_ID="$WRONG_INSTALLATION_ID"
export GITHUB_APP_PRIVATE_KEY_PATH="$WRONG_PEM"
read_static_env_file
if [[ "$GITHUB_APP_ID" == "$CORRECT_APP_ID" ]]; then
  ok "GITHUB_APP_ID overridden to CORRECT value after read"
else
  bad "GITHUB_APP_ID still WRONG after read (got $GITHUB_APP_ID)"
fi
if [[ "$GITHUB_APP_INSTALLATION_ID" == "$CORRECT_INSTALLATION_ID" ]]; then
  ok "GITHUB_APP_INSTALLATION_ID overridden"
else
  bad "GITHUB_APP_INSTALLATION_ID still WRONG (got $GITHUB_APP_INSTALLATION_ID)"
fi
if [[ "$GITHUB_APP_PRIVATE_KEY_PATH" == "$CORRECT_PEM" ]]; then
  ok "GITHUB_APP_PRIVATE_KEY_PATH overridden"
else
  bad "GITHUB_APP_PRIVATE_KEY_PATH still WRONG"
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
