#!/usr/bin/env bash
# gs-stack-status.sh - Show git-spice stack tree with PR review/CI status
#
# Combines `gs ls --all` tree view with GitHub GraphQL API metadata to produce
# an annotated stack tree showing:
#   - PR title
#   - Review status emoji (green/red)
#   - CI status emoji (green/red/yellow)
#   - PR URL on the next line
#   - Current branch highlighted in bold yellow
#   - Aligned columns for easy scanning
#
# Requirements: gs, gh, jq
# Usage: gs-stack-status.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# ANSI color codes
# ---------------------------------------------------------------------------
BOLD_YELLOW='\033[1;33m'
RESET='\033[0m'

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
# Fetch gs ls tree
# ---------------------------------------------------------------------------
gs_tree=$(gs ls --all 2>&1)

# ---------------------------------------------------------------------------
# Extract PR numbers and repo info from gs ls output URLs
# ---------------------------------------------------------------------------
# Parse all PR URLs from gs ls output to get owner, repo, and PR numbers.
# URL format: https://github.com/OWNER/REPO/pull/NUMBER
declare -A pr_number_to_branch
repo_owner=""
repo_name=""

while IFS= read -r line; do
  if [[ "$line" =~ https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    owner="${BASH_REMATCH[1]}"
    name="${BASH_REMATCH[2]}"
    number="${BASH_REMATCH[3]}"

    # Capture repo owner/name from first URL seen
    if [[ -z "$repo_owner" ]]; then
      repo_owner="$owner"
      repo_name="$name"
    fi

    # Extract branch name from the line
    if [[ "$line" =~ [□■][[:space:]]([^[:space:]]+) ]]; then
      branch="${BASH_REMATCH[1]}"
      pr_number_to_branch["$number"]="$branch"
    fi
  fi
done <<< "$gs_tree"

# ---------------------------------------------------------------------------
# Build GraphQL query to fetch PR data for exactly the PRs in the stack
# ---------------------------------------------------------------------------
declare -A pr_title pr_review pr_ci pr_url

if [[ -n "$repo_owner" && ${#pr_number_to_branch[@]} -gt 0 ]]; then
  # Build the query fragment for each PR using aliases
  pr_fragment='
    reviewDecision
    title
    url
    number
    headRefName
    commits(last: 1) {
      nodes {
        commit {
          statusCheckRollup {
            contexts(first: 100) {
              nodes {
                ... on CheckRun { conclusion status }
                ... on StatusContext { state }
              }
            }
          }
        }
      }
    }
  '

  query_body=""
  for number in "${!pr_number_to_branch[@]}"; do
    query_body="${query_body}
    pr${number}: pullRequest(number: ${number}) {
      ${pr_fragment}
    }"
  done

  full_query="query {
    repository(owner: \"${repo_owner}\", name: \"${repo_name}\") {
      ${query_body}
    }
  }"

  # Execute the GraphQL query
  graphql_result=$(gh api graphql -f query="$full_query")

  # ---------------------------------------------------------------------------
  # Parse GraphQL response into lookup arrays
  # ---------------------------------------------------------------------------
  # Process each PR alias from the response
  lookup=$(echo "$graphql_result" | jq -r '
    .data.repository | to_entries[] |
    .value |
    # Review status
    (if .reviewDecision == "APPROVED" then "APPROVED"
     else "NOT_APPROVED"
     end) as $review |
    # CI status: summarize statusCheckRollup contexts
    (
      [(.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // [])[] |
        select(.status != null or .state != null)] |
      if length == 0 then "NO_CI"
      elif any(.conclusion == "FAILURE" or .state == "FAILURE" or .state == "ERROR") then "CI_FAIL"
      elif any(.status == "IN_PROGRESS" or .status == "QUEUED" or .state == "PENDING") then "CI_PENDING"
      elif all(
        .conclusion == "SUCCESS" or .conclusion == "SKIPPED" or
        .conclusion == "NEUTRAL" or .conclusion == "CANCELLED" or
        .state == "SUCCESS"
      ) then
        if any(.conclusion == "SUCCESS" or .state == "SUCCESS") then "CI_PASS"
        else "CI_PENDING"
        end
      else "CI_PENDING"
      end
    ) as $ci |
    "\(.headRefName)\t\(.title)\t\($review)\t\($ci)\t\(.url)"
  ')

  # Load lookup into associative arrays keyed by branch name
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
fi

# ---------------------------------------------------------------------------
# Pass 1: Compute max width of column 1 (tree structure + branch name + marker)
# ---------------------------------------------------------------------------
# Column 1 is the "cleaned line" - the gs ls line with the URL removed.
# We need its *display width* (not byte length) since it contains multi-byte
# box-drawing characters and possibly the ◀ marker.

max_col1_width=0
declare -a cleaned_lines
declare -a branches
declare -a is_current

line_idx=0
while IFS= read -r line; do
  branch=""
  current=0

  # Pattern 1: lines with box-drawing characters (□ or ■ followed by branch name)
  if [[ "$line" =~ [□■][[:space:]]([^[:space:]]+) ]]; then
    branch="${BASH_REMATCH[1]}"
  # Pattern 2: plain trunk line (just a branch name, possibly with whitespace)
  elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_/.-]+)[[:space:]]*$ ]]; then
    branch="${BASH_REMATCH[1]}"
  fi

  # Detect current branch marker
  if [[ "$line" == *"◀"* ]]; then
    current=1
  fi

  if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
    # Strip the PR URL from the gs ls line (we show it on its own line instead)
    cleaned=$(echo "$line" | sed 's| (https://[^)]*)||')

    # Compute display width using wc -m (character count, not bytes)
    # This handles multi-byte UTF-8 box-drawing characters correctly.
    display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')

    if (( display_width > max_col1_width )); then
      max_col1_width=$display_width
    fi
  else
    cleaned="$line"
  fi

  cleaned_lines+=("$cleaned")
  branches+=("$branch")
  is_current+=("$current")
  line_idx=$((line_idx + 1))
done <<< "$gs_tree"

# Add a small gutter between column 1 and column 2
col2_start=$((max_col1_width + 2))

# ---------------------------------------------------------------------------
# Pass 2: Print with aligned columns
# ---------------------------------------------------------------------------
line_idx=0
for cleaned in "${cleaned_lines[@]}"; do
  branch="${branches[$line_idx]}"
  current="${is_current[$line_idx]}"

  if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
    title="${pr_title[$branch]}"
    review="${pr_review[$branch]}"
    ci="${pr_ci[$branch]}"
    url="${pr_url[$branch]}"

    # Compute padding to align column 2
    display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
    padding=$((col2_start - display_width))
    pad_str=$(printf '%*s' "$padding" '')

    # Build the output line: col1 + padding + emojis + title
    output_line="${cleaned}${pad_str}${review}${ci}  ${title}"

    # Build the URL line with indentation aligned under the branch name
    prefix="${cleaned%%"$branch"*}"
    indent="${prefix//[^ ]/ }"
    url_line="${indent}${url}"

    if [[ "$current" -eq 1 ]]; then
      # Current branch: bold yellow highlighting
      printf "${BOLD_YELLOW}%s${RESET}\n" "$output_line"
      printf "${BOLD_YELLOW}%s${RESET}\n" "$url_line"
    else
      echo "$output_line"
      echo "$url_line"
    fi
  else
    # No PR data for this line (trunk, closed PRs, or untracked), print as-is
    if [[ "$current" -eq 1 ]]; then
      printf "${BOLD_YELLOW}%s${RESET}\n" "$cleaned"
    else
      echo "$cleaned"
    fi
  fi

  line_idx=$((line_idx + 1))
done

# ---------------------------------------------------------------------------
# Legend
# ---------------------------------------------------------------------------
echo ""
echo "Legend: [Review][CI] per line"
printf '  \xf0\x9f\x9f\xa2 = approved / passing   \xf0\x9f\x94\xb4 = changes requested / failing\n'
printf '  \xf0\x9f\x9f\xa1 = pending               \xe2\x9a\xaa = no checks\n'
