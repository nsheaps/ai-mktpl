#!/usr/bin/env bash
# git-credential-helper.sh — Git credential helper for GitHub App tokens
#
# This is the CANONICAL source for the credential helper. It is installed to
#   $CLAUDE_SETTINGS_DIR/plugins/data/github-app/git-credential-helper.sh
# at every SessionStart by the github-app plugin's SessionStart hook.
#
# The gitconfig entry that invokes this helper is:
#   [credential "https://github.com"]
#       helper = !<installed-path> <token-file-path>
#
# Git calls this script as: <script> <token-file-path> <action>
#   $1 — absolute path to the token file (embedded in the gitconfig helper line
#         by the plugin hook at write time; must be a resolved, non-env-var path)
#   $2 — git credential action: get | store | erase
#
# The script contains NO hardcoded $HOME or ~/ references. Every path it uses
# comes from $1 (the token file path, passed by git from the gitconfig helper
# line) or from script arguments. This makes the helper portable across users
# and agents on the same machine, each with their own gitconfig entry.
#
# Auto-installed by github-app plugin. Do not configure git with this source
# path directly — use the installed path as printed by github-token-init.sh.
set -euo pipefail

TOKEN_FILE="${1:-}"
ACTION="${2:-}"

case "$ACTION" in
  get)
    if [[ -z "$TOKEN_FILE" ]]; then
      echo "git-credential-helper: token file path not provided as \$1" >&2
      exit 1
    fi
    if [[ ! -f "$TOKEN_FILE" ]]; then
      echo "git-credential-helper: token file not found: $TOKEN_FILE" >&2
      exit 1
    fi
    TOKEN="$(cat "$TOKEN_FILE")"
    if [[ -z "$TOKEN" ]]; then
      echo "git-credential-helper: token file is empty: $TOKEN_FILE" >&2
      exit 1
    fi
    printf 'protocol=https\nhost=github.com\nusername=x-access-token\npassword=%s\n' "$TOKEN"
    ;;
  store|erase)
    # no-op: token lifecycle is managed by the plugin hooks
    ;;
  *)
    # Unknown action — exit cleanly. Some git versions probe the helper
    # or call it without a recognized action during setup/discovery.
    ;;
esac
