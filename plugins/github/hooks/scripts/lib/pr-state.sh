#!/usr/bin/env bash
# pr-state.sh — Library for fetching and caching PR state from GitHub
#
# Fetches PR metadata (comments, reviews, CI status, body, merge status)
# via `gh` CLI and stores snapshots in a local cache directory. On subsequent
# calls, compares the new state against the cached state and reports changes.
#
# Usage:
#   source "${SCRIPT_DIR}/lib/pr-state.sh"
#   pr_state_init "/path/to/cache/dir"
#   pr_state_fetch_and_compare "owner" "repo" "pr_number"
#   # Returns 0 if no changes, 1 if changes detected
#   # Changes are accumulated in PR_STATE_CHANGES array
#
# Requires: gh CLI on PATH, jq on PATH

# Guard against double-sourcing
if [ "${_PR_STATE_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_PR_STATE_LOADED="true"

# --- State ---
_PR_STATE_CACHE_DIR=""
declare -a PR_STATE_CHANGES=()

# Initialize the cache directory.
# Args: $1=cache_dir
pr_state_init() {
  _PR_STATE_CACHE_DIR="$1"
  mkdir -p "$_PR_STATE_CACHE_DIR"
  PR_STATE_CHANGES=()
}

# Fetch current PR state from GitHub and compare against cache.
# Updates the cache file with the new state.
# Args: $1=owner $2=repo $3=pr_number
# Returns: 0 if no changes, 1 if changes detected
# Side effects: populates PR_STATE_CHANGES array
pr_state_fetch_and_compare() {
  local owner="$1" repo="$2" pr_number="$3"
  local cache_file="${_PR_STATE_CACHE_DIR}/${owner}_${repo}_${pr_number}.json"
  local old_state="" new_state=""

  # Load old state if it exists
  if [ -f "$cache_file" ]; then
    old_state="$(cat "$cache_file")"
  fi

  # Fetch new state
  new_state="$(_pr_state_fetch "$owner" "$repo" "$pr_number")" || return 0

  # Save new state
  echo "$new_state" > "$cache_file"

  # If no old state, this is the first fetch — no changes to report
  if [ -z "$old_state" ]; then
    return 0
  fi

  # Compare states
  _pr_state_diff "$old_state" "$new_state" "$owner" "$repo" "$pr_number"
}

# Fetch all PR state into a single JSON object.
# Args: $1=owner $2=repo $3=pr_number
# Returns: JSON string via stdout
_pr_state_fetch() {
  local owner="$1" repo="$2" pr_number="$3"
  local gh_hostname_flag=""

  # In web sessions, gh remote is a proxy — use --hostname
  if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
    gh_hostname_flag="--hostname github.com"
  fi

  # Fetch PR details, reviews, comments, and check runs sequentially
  local pr_json review_json comment_json checks_json

  # PR core data (body, state, mergeable, title, labels, draft)
  # Note: reviewDecision is only available via GraphQL, not REST API
  pr_json="$(gh api ${gh_hostname_flag} \
    "repos/${owner}/${repo}/pulls/${pr_number}" \
    --jq '{
      title: .title,
      body: .body,
      state: .state,
      draft: .draft,
      mergeable: .mergeable,
      mergeable_state: .mergeable_state,
      merged: .merged,
      merge_commit_sha: .merge_commit_sha,
      labels: [.labels[].name],
      head_sha: .head.sha,
      updated_at: .updated_at
    }' 2>/dev/null)" || { echo "{}" ; return 1; }

  # Reviews
  review_json="$(gh api ${gh_hostname_flag} \
    "repos/${owner}/${repo}/pulls/${pr_number}/reviews" \
    --jq '[.[] | {user: .user.login, state: .state, submitted_at: .submitted_at, body: .body}]' \
    2>/dev/null)" || review_json="[]"

  # PR comments (issue comments)
  comment_json="$(gh api ${gh_hostname_flag} \
    "repos/${owner}/${repo}/issues/${pr_number}/comments" \
    --jq '[.[] | {user: .user.login, body: .body, created_at: .created_at, id: .id}]' \
    2>/dev/null)" || comment_json="[]"

  # Review comments (inline code comments)
  local review_comment_json
  review_comment_json="$(gh api ${gh_hostname_flag} \
    "repos/${owner}/${repo}/pulls/${pr_number}/comments" \
    --jq '[.[] | {user: .user.login, body: .body, path: .path, created_at: .created_at, id: .id}]' \
    2>/dev/null)" || review_comment_json="[]"

  # Check runs for head SHA
  local head_sha
  head_sha="$(echo "$pr_json" | jq -r '.head_sha // empty')"
  if [ -n "$head_sha" ]; then
    checks_json="$(gh api ${gh_hostname_flag} \
      "repos/${owner}/${repo}/commits/${head_sha}/check-runs" \
      --jq '{
        total_count: .total_count,
        checks: [.check_runs[] | {name: .name, status: .status, conclusion: .conclusion, completed_at: .completed_at}]
      }' 2>/dev/null)" || checks_json='{"total_count":0,"checks":[]}'
  else
    checks_json='{"total_count":0,"checks":[]}'
  fi

  # Combine into single JSON
  jq -n \
    --argjson pr "$pr_json" \
    --argjson reviews "$review_json" \
    --argjson comments "$comment_json" \
    --argjson review_comments "$review_comment_json" \
    --argjson checks "$checks_json" \
    --arg fetched_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      pr: $pr,
      reviews: $reviews,
      comments: $comments,
      review_comments: $review_comments,
      checks: $checks,
      fetched_at: $fetched_at
    }'
}

# Compare old and new state, populating PR_STATE_CHANGES array.
# Args: $1=old_state_json $2=new_state_json $3=owner $4=repo $5=pr_number
# Returns: 0 if no changes, 1 if changes detected
_pr_state_diff() {
  local old="$1" new="$2" owner="$3" repo="$4" pr_number="$5"
  PR_STATE_CHANGES=()

  # Compare PR body
  local old_body new_body
  old_body="$(echo "$old" | jq -r '.pr.body // ""')"
  new_body="$(echo "$new" | jq -r '.pr.body // ""')"
  if [ "$old_body" != "$new_body" ]; then
    PR_STATE_CHANGES+=("PR body updated on ${owner}/${repo}#${pr_number}")
  fi

  # Compare PR title
  local old_title new_title
  old_title="$(echo "$old" | jq -r '.pr.title // ""')"
  new_title="$(echo "$new" | jq -r '.pr.title // ""')"
  if [ "$old_title" != "$new_title" ]; then
    PR_STATE_CHANGES+=("PR title changed: '${old_title}' -> '${new_title}' on ${owner}/${repo}#${pr_number}")
  fi

  # Compare draft status
  local old_draft new_draft
  old_draft="$(echo "$old" | jq -r '.pr.draft // false')"
  new_draft="$(echo "$new" | jq -r '.pr.draft // false')"
  if [ "$old_draft" != "$new_draft" ]; then
    if [ "$new_draft" = "true" ]; then
      PR_STATE_CHANGES+=("PR ${owner}/${repo}#${pr_number} converted to draft")
    else
      PR_STATE_CHANGES+=("PR ${owner}/${repo}#${pr_number} marked ready for review")
    fi
  fi

  # Compare PR state (open/closed/merged)
  local old_state new_state old_merged new_merged
  old_state="$(echo "$old" | jq -r '.pr.state // ""')"
  new_state="$(echo "$new" | jq -r '.pr.state // ""')"
  old_merged="$(echo "$old" | jq -r '.pr.merged // false')"
  new_merged="$(echo "$new" | jq -r '.pr.merged // false')"
  if [ "$old_state" != "$new_state" ]; then
    if [ "$new_merged" = "true" ] && [ "$old_merged" != "true" ]; then
      PR_STATE_CHANGES+=("PR ${owner}/${repo}#${pr_number} was MERGED")
    else
      PR_STATE_CHANGES+=("PR state changed: ${old_state} -> ${new_state} on ${owner}/${repo}#${pr_number}")
    fi
  fi

  # Compare mergeable status
  local old_mergeable new_mergeable old_mergeable_state new_mergeable_state
  old_mergeable="$(echo "$old" | jq -r '.pr.mergeable // ""')"
  new_mergeable="$(echo "$new" | jq -r '.pr.mergeable // ""')"
  old_mergeable_state="$(echo "$old" | jq -r '.pr.mergeable_state // ""')"
  new_mergeable_state="$(echo "$new" | jq -r '.pr.mergeable_state // ""')"
  if [ "$old_mergeable" != "$new_mergeable" ] || [ "$old_mergeable_state" != "$new_mergeable_state" ]; then
    PR_STATE_CHANGES+=("Merge status changed on ${owner}/${repo}#${pr_number}: mergeable=${old_mergeable}->${new_mergeable}, state=${old_mergeable_state}->${new_mergeable_state}")
  fi

  # Compare labels
  local old_labels new_labels
  old_labels="$(echo "$old" | jq -c '[.pr.labels // [] | sort[]]')"
  new_labels="$(echo "$new" | jq -c '[.pr.labels // [] | sort[]]')"
  if [ "$old_labels" != "$new_labels" ]; then
    PR_STATE_CHANGES+=("Labels changed on ${owner}/${repo}#${pr_number}: ${old_labels} -> ${new_labels}")
  fi

  # Compare reviews (count and latest states)
  local old_review_count new_review_count
  old_review_count="$(echo "$old" | jq '.reviews | length')"
  new_review_count="$(echo "$new" | jq '.reviews | length')"
  if [ "$old_review_count" != "$new_review_count" ]; then
    local new_reviews
    new_reviews="$(echo "$new" | jq -r ".reviews[$old_review_count:][] | \"\(.user) \(.state)\"" 2>/dev/null || true)"
    if [ -n "$new_reviews" ]; then
      while IFS= read -r review_line; do
        PR_STATE_CHANGES+=("New review on ${owner}/${repo}#${pr_number}: ${review_line}")
      done <<< "$new_reviews"
    else
      PR_STATE_CHANGES+=("Reviews changed on ${owner}/${repo}#${pr_number}: ${old_review_count} -> ${new_review_count} reviews")
    fi
  fi

  # Compare comments (count)
  local old_comment_count new_comment_count
  old_comment_count="$(echo "$old" | jq '.comments | length')"
  new_comment_count="$(echo "$new" | jq '.comments | length')"
  if [ "$old_comment_count" != "$new_comment_count" ]; then
    local new_comments
    new_comments="$(echo "$new" | jq -r ".comments[$old_comment_count:][] | \"\(.user): \(.body[0:100])\"" 2>/dev/null || true)"
    if [ -n "$new_comments" ]; then
      while IFS= read -r comment_line; do
        PR_STATE_CHANGES+=("New comment on ${owner}/${repo}#${pr_number}: ${comment_line}")
      done <<< "$new_comments"
    else
      PR_STATE_CHANGES+=("Comments changed on ${owner}/${repo}#${pr_number}: ${old_comment_count} -> ${new_comment_count} comments")
    fi
  fi

  # Compare review comments (inline code comments)
  local old_rc_count new_rc_count
  old_rc_count="$(echo "$old" | jq '.review_comments | length')"
  new_rc_count="$(echo "$new" | jq '.review_comments | length')"
  if [ "$old_rc_count" != "$new_rc_count" ]; then
    local new_rcs
    new_rcs="$(echo "$new" | jq -r ".review_comments[$old_rc_count:][] | \"\(.user) on \(.path): \(.body[0:100])\"" 2>/dev/null || true)"
    if [ -n "$new_rcs" ]; then
      while IFS= read -r rc_line; do
        PR_STATE_CHANGES+=("New review comment on ${owner}/${repo}#${pr_number}: ${rc_line}")
      done <<< "$new_rcs"
    else
      PR_STATE_CHANGES+=("Review comments changed on ${owner}/${repo}#${pr_number}: ${old_rc_count} -> ${new_rc_count}")
    fi
  fi

  # Compare CI check results
  local old_checks new_checks
  old_checks="$(echo "$old" | jq -c '[.checks.checks // [] | sort_by(.name)[] | {name, status, conclusion}]')"
  new_checks="$(echo "$new" | jq -c '[.checks.checks // [] | sort_by(.name)[] | {name, status, conclusion}]')"
  if [ "$old_checks" != "$new_checks" ]; then
    # Find specific check changes
    local check_diff
    check_diff="$(_pr_state_diff_checks "$old" "$new")"
    if [ -n "$check_diff" ]; then
      while IFS= read -r check_line; do
        PR_STATE_CHANGES+=("CI on ${owner}/${repo}#${pr_number}: ${check_line}")
      done <<< "$check_diff"
    else
      PR_STATE_CHANGES+=("CI status changed on ${owner}/${repo}#${pr_number}")
    fi
  fi

  # Return whether changes were detected
  [ ${#PR_STATE_CHANGES[@]} -gt 0 ] && return 1 || return 0
}

# Diff individual check runs between old and new state.
# Args: $1=old_state_json $2=new_state_json
# Returns: human-readable diff lines via stdout
_pr_state_diff_checks() {
  local old="$1" new="$2"

  # Get all check names from both states
  local all_checks
  all_checks="$(jq -r -n \
    --argjson old "$(echo "$old" | jq '.checks.checks // []')" \
    --argjson new "$(echo "$new" | jq '.checks.checks // []')" \
    '[$old[].name, $new[].name] | unique[]')"

  while IFS= read -r check_name; do
    [ -z "$check_name" ] && continue
    local old_status old_conclusion new_status new_conclusion
    old_status="$(echo "$old" | jq -r --arg name "$check_name" '.checks.checks[] | select(.name == $name) | .status // "missing"' | head -1)"
    old_conclusion="$(echo "$old" | jq -r --arg name "$check_name" '.checks.checks[] | select(.name == $name) | .conclusion // "pending"' | head -1)"
    new_status="$(echo "$new" | jq -r --arg name "$check_name" '.checks.checks[] | select(.name == $name) | .status // "missing"' | head -1)"
    new_conclusion="$(echo "$new" | jq -r --arg name "$check_name" '.checks.checks[] | select(.name == $name) | .conclusion // "pending"' | head -1)"

    [ -z "$old_status" ] && old_status="missing"
    [ -z "$new_status" ] && new_status="missing"
    [ -z "$old_conclusion" ] && old_conclusion="pending"
    [ -z "$new_conclusion" ] && new_conclusion="pending"

    if [ "$old_status/$old_conclusion" != "$new_status/$new_conclusion" ]; then
      echo "${check_name}: ${old_status}/${old_conclusion} -> ${new_status}/${new_conclusion}"
    fi
  done <<< "$all_checks"
}

# Get a human-readable summary of all changes.
# Returns: formatted string via stdout
pr_state_changes_summary() {
  if [ ${#PR_STATE_CHANGES[@]} -eq 0 ]; then
    echo "No changes detected"
    return
  fi

  local summary="PR state changes detected:\n"
  for change in "${PR_STATE_CHANGES[@]}"; do
    summary+="  - ${change}\n"
  done
  printf '%b' "$summary"
}
