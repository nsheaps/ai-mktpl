#!/usr/bin/env bash
# Check if gs-stack-status is installed and print install instructions if not

_json_msg() {
  local msg="$1"
  if command -v jq &>/dev/null; then
    jq -n --arg msg "$msg" '{additionalContext: $msg, systemMessage: $msg}'
  else
    local escaped
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "{\"additionalContext\":\"${escaped}\",\"systemMessage\":\"${escaped}\"}"
  fi
}

if ! command -v gs-stack-status &>/dev/null; then
  msg="git-spice: gs-stack-status is not installed. Install it with:
  brew install nsheaps/devsetup/gs-stack-status

gs-stack-status provides a terminal dashboard for git-spice stacked branch workflows."
  echo "$msg" >&2
  _json_msg "$msg"
else
  echo "git-spice: gs-stack-status available" >&2
  _json_msg "git-spice: gs-stack-status available"
fi
