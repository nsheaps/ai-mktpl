#!/usr/bin/env bash
# git-push-wrapper.sh — git push wrapper that auto-sources the GitHub App token
#
# Usage: git-push-wrapper.sh [git push arguments...]
#
# Checks if GH_TOKEN is set. If not, sources the token from the runtime env file
# (GITHUB_APP_ENV_FILE, defaults to ~/.agents/<AGENT_NAME>/.config/github-app-env).
#
# If a token is available after sourcing, uses GIT_ASKPASS to authenticate
# without exposing the token in the process list. Falls back to plain git push
# if no token is available.
#
# Exit codes mirror git push exit codes.

set -euo pipefail

if [[ -z "${GH_TOKEN:-}" ]]; then
  ENV_FILE="${GITHUB_APP_ENV_FILE:-${HOME}/.agents/${AGENT_NAME:-_UNKNOWN}/.config/github-app-env}"
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
  fi
fi

if [[ -n "${GH_TOKEN:-}" ]]; then
  # Parse args: collect flags (anything starting with -) and find the first
  # non-flag positional argument as the remote name, defaulting to 'origin'.
  # This correctly handles patterns like: git push -u origin main
  #
  # Known limitation: only well-known git-push flags with space-separated
  # values are handled. Unknown flags that take a value argument may still
  # cause misidentification of the remote name.
  REMOTE="origin"
  REMOTE_FOUND=false
  SKIP_NEXT=false
  ARGS_WITHOUT_REMOTE=()
  for arg in "$@"; do
    if [[ "$SKIP_NEXT" == true ]]; then
      # This arg is a value for the previous flag, not a remote name
      SKIP_NEXT=false
      ARGS_WITHOUT_REMOTE+=("$arg")
      continue
    fi

    # Flags that take a space-separated value argument (git push docs)
    case "$arg" in
      --push-option|-o|--receive-pack|--exec|--repo|--recurse-submodules|--signed)
        SKIP_NEXT=true
        ARGS_WITHOUT_REMOTE+=("$arg")
        continue
        ;;
    esac

    if [[ "$REMOTE_FOUND" == false && "$arg" != -* ]]; then
      REMOTE="$arg"
      REMOTE_FOUND=true
      # Do NOT add the remote name to ARGS_WITHOUT_REMOTE — it will be
      # replaced by the auth URL when using token-based auth.
    else
      ARGS_WITHOUT_REMOTE+=("$arg")
    fi
  done

  REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || true)

  if [[ -n "$REMOTE_URL" ]] && [[ "$REMOTE_URL" == https://github.com/* ]]; then
    # Use GIT_ASKPASS to supply the token without exposing it in the process
    # list. Embedding the token in the URL (https://x-access-token:TOKEN@...)
    # makes it visible in `ps aux` output. GIT_ASKPASS avoids that by providing
    # the password only on stdout when git's credential system asks for it.
    REPO_PATH="${REMOTE_URL#https://github.com/}"
    AUTH_URL="https://x-access-token@github.com/${REPO_PATH}"

    # Create a temporary GIT_ASKPASS helper that reads the token from the
    # GH_TOKEN env var (already exported). The helper script itself contains
    # no secrets — only a reference to the env var.
    ASKPASS_HELPER=$(mktemp "${TMPDIR:-/tmp}/git-askpass-XXXXXX")
    printf '#!/bin/sh\nprintf "%%s" "$GH_TOKEN"\n' > "$ASKPASS_HELPER"
    chmod +x "$ASKPASS_HELPER"
    trap 'rm -f "$ASKPASS_HELPER"' EXIT

    # Run git push with the auth URL (no embedded password) and the
    # ASKPASS helper supplying the token on demand.
    set +e
    GIT_ASKPASS="$ASKPASS_HELPER" git push "$AUTH_URL" "${ARGS_WITHOUT_REMOTE[@]}" 2>&1
    rc=$?
    set -e
    rm -f "$ASKPASS_HELPER"
    trap - EXIT
    exit "$rc"
  fi

  # Non-https or non-github remote — fall through to plain git push.
  # GH_TOKEN is exported so git credential helpers can also use it.
fi

# No token or non-github URL — fall back to normal git push
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "git-push-wrapper: WARNING: GH_TOKEN is not set, falling back to default git push auth" >&2
fi

exec git push "$@"
