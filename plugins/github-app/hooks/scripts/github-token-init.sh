#!/usr/bin/env bash
# github-token-init.sh — SessionStart hook for github-app plugin
#
# Generates a GitHub App installation token on session start.
# Reads three env vars (injected by the 1pass plugin or any other mechanism):
#   GITHUB_APP_ID
#   GITHUB_INSTALLATION_ID
#   GITHUB_APP_PRIVATE_KEY   (PEM content — not a file path)
#
# Materializes the PEM to $CLAUDE_PLUGIN_DATA/github-app.pem on every session
# start, then generates a token and writes env + git config under $CLAUDE_PLUGIN_DATA/.
set -euo pipefail

PLUGIN_NAME="github-app"


# --- Source shared libs from shared-lib plugin's persistent data dir ---
#
# shared-lib (declared in plugin.json `dependencies`) copies its lib/*.sh
# files into ${CLAUDE_PLUGIN_DATA}/lib on SessionStart. We resolve its data
# dir by stripping our own data-dir name and appending shared-lib's id.
# Plugin data dir IDs are deterministic: `{plugin-name}-{marketplace-name}`.
# See https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
#
# When CLAUDE_PLUGIN_DATA is unset (e.g. when this script is invoked
# outside a Claude Code hook), fall back to the known path.
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

# Wait up to ~10s for a shared-lib file to appear (handles parallel
# SessionStart hooks where shared-lib's copy may not have completed yet).
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[github-app] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "plugin-config-read.sh"
_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/env-file.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/wait-for-env.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }

# --- Check required env vars; wait for them to appear if written by another plugin ---

if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_INSTALLATION_ID:-}" || -z "${GITHUB_APP_PRIVATE_KEY:-}" ]]; then
  hook_log "credentials not yet available, polling CLAUDE_ENV_FILE..."
  TIMEOUT="$(plugin_get_config "waitForEnvTimeoutSeconds" "15")"
  if ! wait_for_env_file GITHUB_APP_ID GITHUB_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY --timeout "${TIMEOUT}"; then
    hook_log "GitHub App not configured (missing GITHUB_APP_ID, GITHUB_INSTALLATION_ID, or GITHUB_APP_PRIVATE_KEY), skipping"
    hook_log_cleanup
    hook_respond; exit 0
  fi
fi

# --- Materialize PEM from env var ---

hook_log_step "materialize-pem" "Writing PEM key to $CLAUDE_PLUGIN_DATA/github-app.pem"

mkdir -p "$CLAUDE_PLUGIN_DATA"
printf '%s\n' "$GITHUB_APP_PRIVATE_KEY" > "$CLAUDE_PLUGIN_DATA/github-app.pem"
chmod 600 "$CLAUDE_PLUGIN_DATA/github-app.pem"

# --- Token generation ---

hook_log_step "generate-token" "Generating GitHub App installation token"

TOKEN_FILE="$CLAUDE_PLUGIN_DATA/github-token"
META_FILE="${TOKEN_FILE}.meta"
mkdir -p "$(dirname "$TOKEN_FILE")"

# Export installation ID so subprocesses can use it
export GITHUB_INSTALLATION_ID
export GITHUB_TOKEN_FILE="$TOKEN_FILE"

# Use the shared JWT generation script
TOKEN_OUTPUT=$("${CLAUDE_PLUGIN_ROOT}/bin/generate-token.sh" \
  "$GITHUB_APP_ID" \
  "$CLAUDE_PLUGIN_DATA/github-app.pem" \
  "$GITHUB_INSTALLATION_ID" \
  "$TOKEN_FILE" 2>&1) || {
  hook_fail "token generation" "Token generation failed: $TOKEN_OUTPUT" \
    "Verify GitHub App credentials (GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, GITHUB_INSTALLATION_ID) are correct and the app is installed on the target org/repo"
  exit 0
}

# Read generated token and metadata for output
TOKEN=$(cat "$TOKEN_FILE")
EXPIRES_AT=""
APP_SLUG=""

if [[ -f "$META_FILE" ]]; then
  EXPIRES_AT=$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null)
fi

# --- GH_CONFIG_DIR isolation ---
# Create an agent-specific, empty gh config directory so that gh never falls
# back to the handler's personal keyring when the App token expires.
# Scoped to CLAUDE_PLUGIN_DATA (per-agent) so multiple agents on the same
# machine or in the same project don't share gh config.

hook_log_step "gh-config-dir" "Creating isolated GH_CONFIG_DIR"

GH_CONFIG_DIR="$CLAUDE_PLUGIN_DATA/gh"
mkdir -p "$GH_CONFIG_DIR"
chmod 700 "$GH_CONFIG_DIR"
export GH_CONFIG_DIR
hook_log "GH_CONFIG_DIR isolated at $GH_CONFIG_DIR"

# --- Write runtime env file ---
# This file is sourced via CLAUDE_ENV_FILE so that subsequent Bash commands
# always pick up the latest token. The PreToolUse hook updates this file
# when it refreshes the token.

hook_log_step "write-env" "Writing runtime environment file"

ENV_RUNTIME_FILE="$CLAUDE_PLUGIN_DATA/github-app-env"
write_runtime_env_file "$TOKEN"

# Source the runtime env file from CLAUDE_ENV_FILE so all Bash commands
# get the token. The file is re-sourced on each command, picking up
# any refreshes done by the PreToolUse hook.
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "source \"$ENV_RUNTIME_FILE\"" >> "$CLAUDE_ENV_FILE"
fi

# --- Configure git identity from GitHub App bot account via env vars ---
#
# Sets GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME, GIT_COMMITTER_EMAIL
# as environment variables instead of writing to git config. This avoids polluting
# the global git config on shared machines where multiple agents may be running.

configure_git_identity_env() {
  local auto_git_config
  auto_git_config="$(plugin_get_config "autoGitConfig" "true")"
  [[ "$auto_git_config" == "true" ]] || return 0

  hook_log_step "git-identity" "Configuring git identity env vars"

  # BUG-7 fix: Never preserve existing git identity from the host machine.
  # On shared machines all agents run as the same OS user and inherit the
  # handler's ~/.gitconfig. We ALWAYS resolve the bot identity from the
  # token metadata and write an isolated GIT_CONFIG_GLOBAL so agents never
  # commit as the handler.

  # Read app slug and bot ID from token metadata (written by generate-token.sh
  # which has JWT auth needed for the /app endpoint — installation tokens
  # cannot access /app).
  local app_slug bot_id
  app_slug=$(jq -r '.app_slug // empty' "$META_FILE" 2>/dev/null) || true
  [[ -n "$app_slug" ]] || { hook_log "WARNING: app_slug not in metadata — git identity not configured"; return 0; }

  bot_id=$(jq -r '.bot_id // empty' "$META_FILE" 2>/dev/null) || true

  # Runtime fallback: if metadata is missing bot_id (older metadata file, or the
  # API was unreachable at token-generation time), try to resolve it now via the
  # PUBLIC /users/<slug>[bot] endpoint. This endpoint requires NO authentication
  # (passing a bearer token there causes 401 — see BUG-7).
  if [[ -z "$bot_id" ]]; then
    hook_log "bot_id missing from metadata — attempting runtime resolution via /users/${app_slug}[bot]"
    local user_resp user_code user_body
    user_resp=$(curl -s -w "\n%{http_code}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/users/${app_slug}%5Bbot%5D" 2>/dev/null) || true
    user_code=$(echo "$user_resp" | tail -1)
    user_body=$(echo "$user_resp" | sed '$d')
    if [[ "$user_code" == "200" ]]; then
      bot_id=$(echo "$user_body" | jq -r '.id // empty' 2>/dev/null) || true
      if [[ -n "$bot_id" ]]; then
        hook_log "Runtime-resolved bot user ID for ${app_slug}[bot]: ${bot_id}"
        # Persist into metadata so we don't repeat the API call on every
        # session start. Use a temp file + mv for atomic update.
        if command -v jq >/dev/null 2>&1 && [[ -w "$META_FILE" ]]; then
          local tmp_meta="${META_FILE}.tmp.$$"
          if jq --arg bid "$bot_id" '.bot_id = $bid' "$META_FILE" > "$tmp_meta" 2>/dev/null; then
            mv "$tmp_meta" "$META_FILE"
            chmod 600 "$META_FILE"
          else
            rm -f "$tmp_meta"
          fi
        fi
      fi
    else
      hook_log "Runtime resolution failed (HTTP ${user_code}): ${user_body}"
    fi
  fi

  local bot_name="${app_slug}[bot]"
  local bot_email
  if [[ -n "$bot_id" ]]; then
    bot_email="${bot_id}+${app_slug}[bot]@users.noreply.github.com"
  else
    # FAIL LOUD: We cannot determine the correct bot user ID. Falling back to
    # GITHUB_APP_ID is wrong — the App ID and bot user ID are different numbers,
    # and commits authored with the App ID in the noreply email will NOT be
    # attributed to the bot account on GitHub. This was the root cause of BUG-7.
    #
    # Rather than silently produce miscredited commits, refuse to configure
    # git identity. Subsequent commits will fail with "Author identity unknown",
    # which is loud and recoverable. The handler can rerun token generation or
    # fix network/API access. Commits silently miscredited to the App ID are
    # NOT recoverable without rewriting history.
    hook_log "ERROR: Could not resolve bot user ID for ${app_slug}[bot]."
    hook_log "ERROR: The /users/${app_slug}[bot] API call failed both at token-generation time and at session-start runtime."
    hook_log "ERROR: Refusing to configure git identity with the wrong email (App ID ${GITHUB_APP_ID} != bot user ID)."
    hook_log "ERROR: Resolve by ensuring api.github.com is reachable, then regenerate the token (delete ${META_FILE} or run bin/generate-token.sh)."
    return 0
  fi

  # --- GIT_CONFIG_GLOBAL isolation ---
  # Write an agent-specific gitconfig file and set GIT_CONFIG_GLOBAL to point
  # to it. This prevents git from reading the handler's ~/.gitconfig, which is
  # the root cause of BUG-7 (agents committing as the handler on shared machines).
  # This mirrors the GH_CONFIG_DIR pattern already used for gh CLI isolation.
  local git_config_file="$CLAUDE_PLUGIN_DATA/git/config"
  mkdir -p "$(dirname "$git_config_file")"

  export GIT_CONFIG_GLOBAL="$git_config_file"
  # BUG-12 fix: use `gh auth git-credential` as the credential helper.
  # Previously we copied a custom script to $CLAUDE_SETTINGS_DIR/plugins/data/
  # and embedded the versioned helper path in gitconfig. Now we write just
  # `!gh auth git-credential` — no script file, no versioned path, no token
  # file path baked into gitconfig. gh reads $GH_TOKEN from the process env
  # (always up-to-date via CLAUDE_ENV_FILE). GH_CONFIG_DIR is already exported
  # per-agent by bin/agent, so gh resolves the correct per-agent config.
  write_git_config_global
  hook_log "GIT_CONFIG_GLOBAL isolated at $git_config_file (credential helper: gh auth git-credential)"

  # Defense-in-depth: also set GIT_AUTHOR_*/GIT_COMMITTER_* env vars.
  # These take precedence over gitconfig, so even if GIT_CONFIG_GLOBAL is
  # somehow bypassed, commits still use the bot identity.
  export GIT_AUTHOR_NAME="$bot_name"
  export GIT_AUTHOR_EMAIL="$bot_email"
  export GIT_COMMITTER_NAME="$bot_name"
  export GIT_COMMITTER_EMAIL="$bot_email"

  # Rewrite the runtime env file now that identity vars are in the environment
  write_runtime_env_file "$TOKEN"

  # Write a separate stable file that is NOT overwritten by token refreshes.
  # This is defense-in-depth: even if the env file template drifts, the
  # git identity file remains correct for the lifetime of the session.
  write_git_identity_file "$bot_name" "$bot_email"

  # Source the stable git identity file from CLAUDE_ENV_FILE after the
  # runtime env file. It takes precedence if the runtime env file ever
  # loses the identity vars (e.g., due to future template drift).
  # Also persist GIT_CONFIG_GLOBAL so subprocesses inherit gitconfig isolation.
  if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "export GIT_CONFIG_GLOBAL=\"$git_config_file\"" >> "$CLAUDE_ENV_FILE"
    echo "source \"$GIT_IDENTITY_FILE\"" >> "$CLAUDE_ENV_FILE"
  fi

  hook_log "Configured git identity env vars: $bot_name <$bot_email>"
  hook_log "Git identity written to stable file: $GIT_IDENTITY_FILE"

  # Save slug for use by hook output logging
  APP_SLUG="$app_slug"
}

configure_git_identity_env

# --- Print initial token info ---

hook_log "Authenticated as ${APP_SLUG:-app-$GITHUB_APP_ID} (expires: ${EXPIRES_AT:-unknown})"
hook_log "Token available via \$GH_TOKEN and \$GITHUB_TOKEN"

hook_log_cleanup
hook_respond
