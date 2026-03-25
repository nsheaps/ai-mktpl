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
  mkdir -p -m 700 "$_PR_STATE_CACHE_DIR"
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

  # Atomic cache write: write to temp file then rename
  local tmp_file="${cache_file}.tmp.$$"
  echo "$new_state" > "$tmp_file"
  mv -f "$tmp_file" "$cache_file"

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

  # Check runs for head SHA — validate SHA format before using in URL
  local head_sha
  head_sha="$(echo "$pr_json" | jq -r '.head_sha // empty')"
  if [ -n "$head_sha" ] && [[ "$head_sha" =~ ^[0-9a-f]{7,40}$ ]]; then
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
# Uses a single jq call to extract all comparable fields from both states,
# then compares in bash to generate human-readable change messages.
# Args: $1=old_state_json $2=new_state_json $3=owner $4=repo $5=pr_number
# Returns: 0 if no changes, 1 if changes detected
_pr_state_diff() {
  local old="$1" new="$2" owner="$3" repo="$4" pr_number="$5"
  local prefix="${owner}/${repo}#${pr_number}"
  PR_STATE_CHANGES=()

  # Extract all comparable fields from both old and new state in a single jq call.
  # Output is a tab-separated line per field: "field_name\told_value\tnew_value"
  local diff_output
  diff_output="$(jq -r -n \
    --argjson old "$old" \
    --argjson new "$new" \
    '
    def s: . // "";
    def sorted_labels: [. // [] | sort[]];

    # Scalar PR fields
    [
      ["body",            ($old.pr.body | s),             ($new.pr.body | s)],
      ["title",           ($old.pr.title | s),            ($new.pr.title | s)],
      ["draft",           ($old.pr.draft | tostring),     ($new.pr.draft | tostring)],
      ["state",           ($old.pr.state | s),            ($new.pr.state | s)],
      ["merged",          ($old.pr.merged | tostring),    ($new.pr.merged | tostring)],
      ["mergeable",       ($old.pr.mergeable | s),        ($new.pr.mergeable | s)],
      ["mergeable_state", ($old.pr.mergeable_state | s),  ($new.pr.mergeable_state | s)],
      ["labels",          ($old.pr.labels | sorted_labels | tojson), ($new.pr.labels | sorted_labels | tojson)],
      ["review_count",    ($old.reviews | length | tostring),        ($new.reviews | length | tostring)],
      ["comment_count",   ($old.comments | length | tostring),       ($new.comments | length | tostring)],
      ["rc_count",        ($old.review_comments | length | tostring),($new.review_comments | length | tostring)],
      ["checks",          ([$old.checks.checks // [] | sort_by(.name)[] | {name,status,conclusion}] | tojson),
                          ([$new.checks.checks // [] | sort_by(.name)[] | {name,status,conclusion}] | tojson)]
    ]
    | .[] | select(.[1] != .[2]) | @tsv
    ')" || return 0

  # No differences found
  if [ -z "$diff_output" ]; then
    return 0
  fi

  # Process each changed field
  while IFS=$'\t' read -r field old_val new_val; do
    case "$field" in
      body)
        PR_STATE_CHANGES+=("PR body updated on ${prefix}")
        ;;
      title)
        PR_STATE_CHANGES+=("PR title changed: '${old_val}' -> '${new_val}' on ${prefix}")
        ;;
      draft)
        if [ "$new_val" = "true" ]; then
          PR_STATE_CHANGES+=("PR ${prefix} converted to draft")
        else
          PR_STATE_CHANGES+=("PR ${prefix} marked ready for review")
        fi
        ;;
      state)
        if [ "$new_val" = "closed" ] && _pr_check_merged "$new" ; then
          PR_STATE_CHANGES+=("PR ${prefix} was MERGED")
        else
          PR_STATE_CHANGES+=("PR state changed: ${old_val} -> ${new_val} on ${prefix}")
        fi
        ;;
      merged)
        # Handled by state change above; only fire if state didn't change
        ;;
      mergeable|mergeable_state)
        PR_STATE_CHANGES+=("Merge status changed on ${prefix}: ${field}=${old_val}->${new_val}")
        ;;
      labels)
        PR_STATE_CHANGES+=("Labels changed on ${prefix}: ${old_val} -> ${new_val}")
        ;;
      review_count)
        _pr_state_diff_new_reviews "$new" "$old_val" "$prefix"
        ;;
      comment_count)
        _pr_state_diff_new_comments "$new" "$old_val" "$prefix" "comments" "comment"
        ;;
      rc_count)
        _pr_state_diff_new_review_comments "$new" "$old_val" "$prefix"
        ;;
      checks)
        _pr_state_diff_checks_unified "$old" "$new" "$prefix"
        ;;
    esac
  done <<< "$diff_output"

  [ ${#PR_STATE_CHANGES[@]} -gt 0 ] && return 1 || return 0
}

# Check if a PR state JSON shows merged=true
_pr_check_merged() {
  local state="$1"
  [ "$(echo "$state" | jq -r '.pr.merged')" = "true" ]
}

# Extract and report new reviews (single jq call).
_pr_state_diff_new_reviews() {
  local new="$1" old_count="$2" prefix="$3"
  local new_reviews
  new_reviews="$(echo "$new" | jq -r --argjson skip "$old_count" \
    '.reviews[$skip:][] | "\(.user) \(.state)"' 2>/dev/null || true)"
  if [ -n "$new_reviews" ]; then
    while IFS= read -r line; do
      PR_STATE_CHANGES+=("New review on ${prefix}: ${line}")
    done <<< "$new_reviews"
  else
    PR_STATE_CHANGES+=("Reviews changed on ${prefix}")
  fi
}

# Extract and report new comments (single jq call).
_pr_state_diff_new_comments() {
  local new="$1" old_count="$2" prefix="$3" field="$4" label="$5"
  local new_items
  new_items="$(echo "$new" | jq -r --argjson skip "$old_count" \
    ".${field}"'[$skip:][] | "\(.user): \(.body[0:100])"' 2>/dev/null || true)"
  if [ -n "$new_items" ]; then
    while IFS= read -r line; do
      PR_STATE_CHANGES+=("New ${label} on ${prefix}: ${line}")
    done <<< "$new_items"
  else
    PR_STATE_CHANGES+=("${label}s changed on ${prefix}")
  fi
}

# Extract and report new review comments (single jq call).
_pr_state_diff_new_review_comments() {
  local new="$1" old_count="$2" prefix="$3"
  local new_rcs
  new_rcs="$(echo "$new" | jq -r --argjson skip "$old_count" \
    '.review_comments[$skip:][] | "\(.user) on \(.path): \(.body[0:100])"' 2>/dev/null || true)"
  if [ -n "$new_rcs" ]; then
    while IFS= read -r line; do
      PR_STATE_CHANGES+=("New review comment on ${prefix}: ${line}")
    done <<< "$new_rcs"
  else
    PR_STATE_CHANGES+=("Review comments changed on ${prefix}")
  fi
}

# Diff CI check runs using a single jq call that joins old and new by name.
# Args: $1=old_state_json $2=new_state_json $3=prefix
_pr_state_diff_checks_unified() {
  local old="$1" new="$2" prefix="$3"
  local check_diff
  check_diff="$(jq -r -n \
    --argjson old_checks "$(echo "$old" | jq '.checks.checks // []')" \
    --argjson new_checks "$(echo "$new" | jq '.checks.checks // []')" \
    '
    # Index checks by name
    def by_name: [.[] | {key: .name, value: {s: .status, c: (.conclusion // "pending")}}] | from_entries;
    ($old_checks | by_name) as $o |
    ($new_checks | by_name) as $n |
    ([$o | keys[], $n | keys[]] | unique[]) as $name |
    ($o[$name] // {s:"missing",c:"pending"}) as $ov |
    ($n[$name] // {s:"missing",c:"pending"}) as $nv |
    select("\($ov.s)/\($ov.c)" != "\($nv.s)/\($nv.c)") |
    "\($name): \($ov.s)/\($ov.c) -> \($nv.s)/\($nv.c)"
    ')" || true

  if [ -n "$check_diff" ]; then
    while IFS= read -r line; do
      PR_STATE_CHANGES+=("CI on ${prefix}: ${line}")
    done <<< "$check_diff"
  else
    PR_STATE_CHANGES+=("CI status changed on ${prefix}")
  fi
}
