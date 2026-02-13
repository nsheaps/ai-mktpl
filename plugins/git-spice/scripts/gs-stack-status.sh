#!/usr/bin/env bash
# gs-stack-status.sh - Show git-spice stack tree with PR review/CI status
#
# Combines `gs ls --all` tree view with `gh pr list` metadata to produce
# an annotated stack tree showing:
#   - PR title
#   - Review status emoji (green/red)
#   - CI status emoji (green/red/yellow)
#   - PR URL on the next line
#
# Requirements: gs, gh, jq
# Usage: gs-stack-status.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
for cmd in gs gh jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found in PATH" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Fetch data
# ---------------------------------------------------------------------------
gs_tree=$(gs ls --all 2>&1)

pr_json=$(gh pr list \
  --author @me \
  --state open \
  --limit 200 \
  --json number,title,url,headRefName,reviewDecision,statusCheckRollup)

# ---------------------------------------------------------------------------
# Build a lookup from branch name -> PR data using jq
# ---------------------------------------------------------------------------
# Produces lines of: branchName<TAB>title<TAB>reviewStatus<TAB>ciStatus<TAB>url
# We use marker strings (not emojis) so bash can reliably parse the TSV.
lookup=$(echo "$pr_json" | jq -r '
  .[] |
  # Review status
  (if .reviewDecision == "APPROVED" then "APPROVED"
   else "NOT_APPROVED"
   end) as $review |
  # CI status: summarize statusCheckRollup
  # Ignore SKIPPED-only and CANCELLED-only entries; focus on meaningful results.
  (
    [.statusCheckRollup[] | select(.status != null)] |
    if length == 0 then "NO_CI"
    elif any(.conclusion == "FAILURE") then "CI_FAIL"
    elif any(.status == "IN_PROGRESS" or .status == "QUEUED") then "CI_PENDING"
    elif all(.conclusion == "SUCCESS" or .conclusion == "SKIPPED" or .conclusion == "NEUTRAL" or .conclusion == "CANCELLED") then
      # If everything is cancelled/skipped (nothing actually succeeded), treat as pending
      if any(.conclusion == "SUCCESS") then "CI_PASS"
      else "CI_PENDING"
      end
    else "CI_PENDING"
    end
  ) as $ci |
  "\(.headRefName)\t\(.title)\t\($review)\t\($ci)\t\(.url)"
')

# Load lookup into an associative array keyed by branch name
declare -A pr_title pr_review pr_ci pr_url

while IFS=$'\t' read -r branch title review ci url; do
  [[ -z "$branch" ]] && continue

  case "$review" in
    APPROVED)     review_emoji=$'\xf0\x9f\x9f\xa2' ;;  # green circle
    *)            review_emoji=$'\xf0\x9f\x94\xb4' ;;  # red circle
  esac
  case "$ci" in
    CI_PASS)      ci_emoji=$'\xf0\x9f\x9f\xa2' ;;      # green circle
    CI_FAIL)      ci_emoji=$'\xf0\x9f\x94\xb4' ;;      # red circle
    CI_PENDING)   ci_emoji=$'\xf0\x9f\x9f\xa1' ;;      # yellow circle
    NO_CI)        ci_emoji=$'\xe2\x9a\xaa' ;;           # white circle
    *)            ci_emoji=$'\xf0\x9f\x9f\xa1' ;;      # yellow circle
  esac

  pr_title["$branch"]="$title"
  pr_review["$branch"]="$review_emoji"
  pr_ci["$branch"]="$ci_emoji"
  pr_url["$branch"]="$url"
done <<< "$lookup"

# ---------------------------------------------------------------------------
# Process tree output line by line
# ---------------------------------------------------------------------------
# Each line from `gs ls --all` looks like one of:
#   ┣━□ branch-name (https://...) [optional notes like "(needs restack)"]
#   ┣━■ branch-name (https://...) ◀        (current branch, filled square)
#   main                                    (trunk, no decoration)
#
# Strategy: extract the branch name from each line, look up PR data,
# then append status emojis and print the PR URL on the next line.

while IFS= read -r line; do
  branch=""

  # Pattern 1: lines with box-drawing characters (□ or ■ followed by branch name)
  if [[ "$line" =~ [□■][[:space:]]([^[:space:]]+) ]]; then
    branch="${BASH_REMATCH[1]}"
  # Pattern 2: plain trunk line (just a branch name, possibly with whitespace)
  elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_/.-]+)[[:space:]]*$ ]]; then
    branch="${BASH_REMATCH[1]}"
  fi

  if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
    title="${pr_title[$branch]}"
    review="${pr_review[$branch]}"
    ci="${pr_ci[$branch]}"
    url="${pr_url[$branch]}"

    # Strip the PR URL from the gs ls line (we show it on its own line instead)
    # Uses sed because bash parameter expansion doesn't support [^)]* patterns.
    cleaned_line=$(echo "$line" | sed 's| (https://[^)]*)||')

    # Print the annotated branch line
    echo "${cleaned_line}  ${review} ${ci}  ${title}"

    # For the URL line, create indentation matching the branch name position.
    # We find everything before the branch name and replace non-space chars
    # with spaces to get proper alignment.
    prefix="${line%%"$branch"*}"
    indent="${prefix//[^ ]/ }"
    echo "${indent}${url}"
  else
    # No PR data for this line (trunk, closed PRs, or untracked), print as-is
    echo "$line"
  fi
done <<< "$gs_tree"
