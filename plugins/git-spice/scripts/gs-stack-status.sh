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
# Requirements: gs, gh, jq, python3
# Usage: gs-stack-status.sh [--output interactive|markdown|iterm] [--no-status]
#        [--reviewed] [--no-reviewed] [--failing-ci] [--no-failing-ci]
#        [--color] [--no-color] [--watch [SECONDS]]

set -euo pipefail

ORIGINAL_ARGS=("$@")

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OUTPUT_FORMAT="interactive"
SHOW_STATUS=1
FILTER_REVIEWED=""       # "yes" = only reviewed, "no" = only NOT reviewed, "" = no filter
FILTER_FAILING_CI=""     # "yes" = only failing CI, "no" = only NOT failing CI, "" = no filter
COLOR_OVERRIDE=""        # "yes" = force color, "no" = force no color, "" = auto-detect TTY
WATCH_MODE=0
WATCH_INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --output requires a value (interactive or markdown)" >&2
        exit 1
      fi
      OUTPUT_FORMAT="$2"
      if [[ "$OUTPUT_FORMAT" != "interactive" && "$OUTPUT_FORMAT" != "markdown" && "$OUTPUT_FORMAT" != "iterm" ]]; then
        echo "ERROR: --output must be 'interactive', 'markdown', or 'iterm'" >&2
        exit 1
      fi
      shift 2
      ;;
    --no-status)
      SHOW_STATUS=0
      shift
      ;;
    --reviewed)
      FILTER_REVIEWED="yes"
      shift
      ;;
    --no-reviewed)
      FILTER_REVIEWED="no"
      shift
      ;;
    --failing-ci)
      FILTER_FAILING_CI="yes"
      shift
      ;;
    --no-failing-ci)
      FILTER_FAILING_CI="no"
      shift
      ;;
    --color)
      COLOR_OVERRIDE="yes"
      shift
      ;;
    --no-color)
      COLOR_OVERRIDE="no"
      shift
      ;;
    --watch)
      WATCH_MODE=1
      if [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]]; then
        WATCH_INTERVAL="$2"
        shift 2
      else
        shift
      fi
      ;;
    -h|--help)
      echo "Usage: gs-stack-status.sh [--output interactive|markdown|iterm] [--no-status]"
      echo "       [--reviewed] [--no-reviewed] [--failing-ci] [--no-failing-ci]"
      echo "       [--color] [--no-color] [--watch [SECONDS]]"
      echo ""
      echo "Options:"
      echo "  --output FORMAT   Output format: interactive (default), markdown, or iterm"
      echo "  --no-status       Omit review/CI emoji indicators"
      echo "  --reviewed        Only show PRs that have been reviewed/approved"
      echo "  --no-reviewed     Only show PRs that have NOT been reviewed/approved"
      echo "  --failing-ci      Only show PRs where CI is failing"
      echo "  --no-failing-ci   Only show PRs where CI is NOT failing"
      echo "  --color           Force color output even when not a TTY"
      echo "  --no-color        Suppress color/escape codes even when on a TTY"
      echo "  --watch [SECS]    Refresh in-place every SECS seconds (default: 5)"
      echo "  -h, --help        Show this help message"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option '$1'" >&2
      echo "Usage: gs-stack-status.sh [--output interactive|markdown|iterm] [--no-status] [--color] [--no-color] [--watch [SECS]]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Watch mode: re-invoke self in a loop, replacing screen contents in place.
# Uses cursor-home + clear-to-end instead of `clear` to avoid flicker,
# and preserves full terminal capabilities (OSC 8 hyperlinks, etc.).
# ---------------------------------------------------------------------------
if [[ "$WATCH_MODE" -eq 1 && "${_GS_STATUS_WATCHING:-}" != "1" ]]; then
  export _GS_STATUS_WATCHING=1
  export FORCE_COLOR=1

  # Build args for child invocations: strip --watch and its optional interval
  child_args=()
  skip_next=0
  for arg in "${ORIGINAL_ARGS[@]}"; do
    if [[ "$skip_next" -eq 1 ]]; then
      # Only skip if it looks like an interval number (matches parser behavior)
      if [[ "$arg" =~ ^[0-9]+$ ]]; then
        skip_next=0
        continue
      fi
      skip_next=0
    fi
    if [[ "$arg" == "--watch" ]]; then
      skip_next=1
      continue
    fi
    child_args+=("$arg")
  done

  # Hide cursor for cleaner display, restore on exit
  cleanup() { printf '\033[?25h'; }
  trap cleanup EXIT INT TERM
  printf '\033[?25l'

  while true; do
    printf '\033[H'                        # cursor to home
    "$0" "${child_args[@]}" 2>&1 || true   # run script, don't exit on failure
    printf '\033[J'                        # clear from cursor to end of screen
    sleep "$WATCH_INTERVAL"
  done
fi

# ---------------------------------------------------------------------------
# TTY detection and color support
# ---------------------------------------------------------------------------
# Auto-detect whether to use color based on TTY, allow explicit override.
# Supports FORCE_COLOR=1 env var (common convention, e.g. chalk, jest, etc.)
if [[ "$COLOR_OVERRIDE" == "yes" ]] || [[ "${FORCE_COLOR:-}" == "1" ]]; then
  USE_COLOR=1
elif [[ "$COLOR_OVERRIDE" == "no" ]]; then
  USE_COLOR=0
elif [[ -t 1 ]]; then
  USE_COLOR=1
else
  USE_COLOR=0
fi

# When --no-color is set and output is iterm, fall back to interactive mode
# since iterm mode relies on OSC 8 escape codes for hyperlinks.
if [[ "$USE_COLOR" -eq 0 && "$OUTPUT_FORMAT" == "iterm" ]]; then
  OUTPUT_FORMAT="interactive"
fi

# Define color variables conditionally
if [[ "$USE_COLOR" -eq 1 ]]; then
  BOLD_YELLOW=$'\033[1;33m'
  RED=$'\033[0;31m'
  RESET=$'\033[0m'
else
  BOLD_YELLOW=""
  RED=""
  RESET=""
fi

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
required_cmds=(gs gh jq)
if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
  required_cmds+=(python3)
fi
for cmd in "${required_cmds[@]}"; do
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
declare -A branch_to_pr_number
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
      branch_to_pr_number["$branch"]="$number"
    fi
  fi
done <<< "$gs_tree"

# ---------------------------------------------------------------------------
# Build GraphQL query to fetch PR data for exactly the PRs in the stack
# ---------------------------------------------------------------------------
declare -A pr_title pr_review pr_ci pr_url pr_review_raw pr_ci_raw pr_state

if [[ -n "$repo_owner" && ${#pr_number_to_branch[@]} -gt 0 ]]; then
  # Build the query fragment for each PR using aliases.
  # We use statusCheckRollup.state for CI status — it is the GitHub-computed
  # rollup that correctly deduplicates re-run checks (the per-context nodes
  # include ALL historical runs, causing false FAILUREs from cancelled runs).
  pr_fragment='
    reviewDecision
    state
    title
    url
    number
    headRefName
    commits(last: 1) {
      nodes {
        commit {
          statusCheckRollup {
            state
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
    # CI status: use the GitHub-computed rollup state which correctly handles
    # re-runs and deduplication (statusCheckRollup.state).
    # Possible values: SUCCESS, FAILURE, PENDING, ERROR, EXPECTED, null
    (
      (.commits.nodes[0].commit.statusCheckRollup.state // null) |
      if . == null then "NO_CI"
      elif . == "SUCCESS" then "CI_PASS"
      elif . == "FAILURE" or . == "ERROR" then "CI_FAIL"
      elif . == "PENDING" or . == "EXPECTED" then "CI_PENDING"
      else "CI_PENDING"
      end
    ) as $ci |
    "\(.headRefName)\t\(.title)\t\($review)\t\($ci)\t\(.url)\t\(.state)"
  ')

  # Load lookup into associative arrays keyed by branch name
  while IFS=$'\t' read -r branch title review ci url state; do
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
    pr_review_raw["$branch"]="$review"
    pr_ci_raw["$branch"]="$ci"
    pr_state["$branch"]="$state"
  done <<< "$lookup"
fi

# ---------------------------------------------------------------------------
# Filtering logic
# ---------------------------------------------------------------------------
# Determine whether a branch should be filtered out based on --reviewed,
# --no-reviewed, --failing-ci, --no-failing-ci flags.
#
# Returns 0 (true) if the branch should be SHOWN, 1 if it should be HIDDEN.
# Branches without PRs and the current branch are never filtered.
branch_passes_filter() {
  local branch="$1"
  local current="$2"  # 1 if current branch

  # Current branch is never filtered out
  if [[ "$current" -eq 1 ]]; then
    return 0
  fi

  # Branches without PRs (like main) are never filtered out
  if [[ -z "${pr_review_raw[$branch]+_}" ]]; then
    return 0
  fi

  # No filters active — show everything
  if [[ -z "$FILTER_REVIEWED" && -z "$FILTER_FAILING_CI" ]]; then
    return 0
  fi

  local review_raw="${pr_review_raw[$branch]}"
  local ci_raw="${pr_ci_raw[$branch]}"

  # Check review filter
  if [[ "$FILTER_REVIEWED" == "yes" && "$review_raw" != "APPROVED" ]]; then
    return 1
  fi
  if [[ "$FILTER_REVIEWED" == "no" && "$review_raw" == "APPROVED" ]]; then
    return 1
  fi

  # Check CI filter
  if [[ "$FILTER_FAILING_CI" == "yes" && "$ci_raw" != "CI_FAIL" ]]; then
    return 1
  fi
  if [[ "$FILTER_FAILING_CI" == "no" && "$ci_raw" == "CI_FAIL" ]]; then
    return 1
  fi

  return 0
}

# ===========================================================================
# Output: Markdown format
# ===========================================================================
if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
  # -------------------------------------------------------------------------
  # Compute depth for each branch using python3 to parse the tree structure.
  # The gs ls tree grows upward: children are listed ABOVE their parents.
  # Process bottom-to-top to determine depth.
  # -------------------------------------------------------------------------
  declare -A branch_depth

  depth_output=$(python3 -c "
import sys

lines = []
for line in sys.stdin:
    lines.append(line.rstrip('\n'))

# Process bottom-to-top to determine depth.
# The gs ls tree grows upward: children are listed ABOVE their parents.
#
# Tree characters:
#   ┣  = branch from trunk (sibling connector)
#   ┏  = start of upward chain
#   ┻  = merge point (children are above this line)
#   ┃  = vertical continuation (pipe) of a parent branch
#   □/■ = branch marker (□ = not current, ■ = current)
#
# Algorithm (bottom-to-top processing):
# 1. 'main' (trunk with no tree chars) = depth 0
# 2. ┣ lines = depth 1 (directly on trunk); ┣━┻ sets up counter for children above
# 3. ┏ at trunk level (pipes=0) = depth 1 if starting a new chain, or continues
#    an existing counter from a preceding ┣━┻
# 4. Lines in sub-trees (pipes>0) get depth = pipes+1 and increment within their sub-tree
# 5. Each ┣ line resets all sub-tree counters (new independent trunk branch)

results = []
reversed_lines = list(reversed(lines))

trunk_next_depth = None   # counter for trunk-level upward chains
sub_next_depth = {}       # key: pipe count, value: next depth for that sub-tree level

for line in reversed_lines:
    if not line.strip():
        continue

    is_current = '\u25c0' in line  # ◀

    branch = None
    box_col = -1
    for i, ch in enumerate(line):
        if ch in '\u25a1\u25a0':  # □ or ■
            rest = line[i+1:].strip()
            branch = rest.split()[0] if rest else None
            box_col = i
            break

    if branch is None:
        name = line.strip()
        if name:
            results.append((name, 0, is_current))
        continue

    prefix = line[:box_col]
    pipes = prefix.count('\u2503')    # ┃
    has_trunk = '\u2523' in prefix    # ┣
    has_merge = '\u253b' in prefix    # ┻
    has_fork = '\u250f' in prefix     # ┏

    if has_trunk:
        # Direct trunk connector — always depth 1
        depth = 1
        sub_next_depth = {}  # reset sub-tree counters for new trunk branch
        if has_merge:
            trunk_next_depth = 2  # children above start at depth 2
        else:
            trunk_next_depth = None
    elif pipes == 0 and has_fork:
        # ┏ at trunk level (no pipes) — also a trunk branch
        if trunk_next_depth is not None:
            # Continuing an upward chain set up by a preceding ┣━┻
            depth = trunk_next_depth
            trunk_next_depth = depth + 1
        else:
            # New trunk chain (no preceding ┣━┻ set it up)
            depth = 1
            if has_merge:
                trunk_next_depth = depth + 1
            else:
                trunk_next_depth = None
    elif pipes == 0:
        # Trunk chain line without ┏ (fallback)
        if trunk_next_depth is not None:
            depth = trunk_next_depth
            trunk_next_depth = depth + 1
        else:
            depth = 2
            trunk_next_depth = 3
    else:
        # Sub-tree line (has ┃ pipes)
        key = pipes
        if key in sub_next_depth:
            depth = sub_next_depth[key]
            sub_next_depth[key] = depth + 1
        else:
            depth = pipes + 1
            sub_next_depth[key] = depth + 1

    results.append((branch, depth, is_current))

# Output in the correct (top-to-bottom) order
for branch, depth, is_current in reversed(results):
    current_flag = '1' if is_current else '0'
    print(f'{branch}\t{depth}\t{current_flag}')
" <<< "$gs_tree")

  while IFS=$'\t' read -r branch depth current_flag; do
    [[ -z "$branch" ]] && continue
    branch_depth["$branch"]="$depth"
  done <<< "$depth_output"

  # -------------------------------------------------------------------------
  # Generate markdown output (with filtering support)
  # -------------------------------------------------------------------------
  # Process lines in the original gs ls order (top-to-bottom)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    branch=""
    current=0

    # Detect current branch
    if [[ "$line" == *"◀"* ]]; then
      current=1
    fi

    # Extract branch name
    if [[ "$line" =~ [□■][[:space:]]([^[:space:]]+) ]]; then
      branch="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_/.-]+)[[:space:]]*$ ]]; then
      branch="${BASH_REMATCH[1]}"
    fi

    [[ -z "$branch" ]] && continue

    depth="${branch_depth[$branch]:-0}"

    # Compute indentation: 2 spaces per depth level (depth 1 = no indent, depth 2 = 2 spaces, etc.)
    indent=""
    if (( depth > 1 )); then
      indent=$(printf '%*s' $(( (depth - 1) * 2 )) '')
    fi

    # Filtered branches are silently skipped (no placeholder)
    if ! branch_passes_filter "$branch" "$current"; then
      continue
    fi

    # Build the markdown line
    if [[ -n "${pr_title[$branch]+_}" ]]; then
      title="${pr_title[$branch]}"
      url="${pr_url[$branch]}"
      pr_num="${branch_to_pr_number[$branch]}"

      # Prepend ⛔️ for closed/merged PRs
      closed_prefix=""
      if [[ "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ]]; then
        closed_prefix=$'\xe2\x9b\x94\xef\xb8\x8f '
      fi

      if [[ "$SHOW_STATUS" -eq 1 ]]; then
        review="${pr_review[$branch]}"
        ci="${pr_ci[$branch]}"
        link_text="${closed_prefix}${review}${ci} #${pr_num} ${title}"
      else
        link_text="${closed_prefix}#${pr_num} ${title}"
      fi

      if [[ "$current" -eq 1 ]]; then
        md_line="${indent}- **[${link_text}](${url})**"
      else
        md_line="${indent}- [${link_text}](${url})"
      fi
    else
      # No PR (trunk branch like main)
      if [[ "$current" -eq 1 ]]; then
        md_line="${indent}- **${branch}**"
      else
        md_line="${indent}- ${branch}"
      fi
    fi

    echo "$md_line"
  done <<< "$gs_tree"

  # -------------------------------------------------------------------------
  # Legend (only with status)
  # -------------------------------------------------------------------------
  if [[ "$SHOW_STATUS" -eq 1 ]]; then
    echo ""
    printf 'Legend: [Review][CI] — '
    printf '\xf0\x9f\x9f\xa2 approved/passing  '
    printf '\xf0\x9f\x94\xb4 changes requested/failing  '
    printf '\xf0\x9f\x9f\xa1 pending  '
    printf '\xe2\x9a\xaa no checks\n'
  fi

  exit 0
fi

# ===========================================================================
# Output: iTerm format (OSC 8 clickable hyperlinks)
# ===========================================================================
# Uses iTerm2 OSC 8 escape codes to make branch+title a clickable hyperlink.
# Same tree structure as interactive mode but no separate URL line beneath.
# Format: \033]8;;URL\033\\DISPLAY TEXT\033]8;;\033\\

if [[ "$OUTPUT_FORMAT" == "iterm" ]]; then
  # -------------------------------------------------------------------------
  # Pass 1: Compute max width of column 1 (tree prefix + branch name)
  # -------------------------------------------------------------------------
  max_col1_width=0
  declare -a iterm_cleaned_lines
  declare -a iterm_branches
  declare -a iterm_is_current

  line_idx=0
  while IFS= read -r line; do
    branch=""
    current=0

    if [[ "$line" =~ [□■][[:space:]]([^[:space:]]+) ]]; then
      branch="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_/.-]+)[[:space:]]*$ ]]; then
      branch="${BASH_REMATCH[1]}"
    fi

    if [[ "$line" == *"◀"* ]]; then
      current=1
    fi

    if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
      cleaned=$(echo "$line" | sed 's| (https://[^)]*)||')
      display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
      if (( display_width > max_col1_width )); then
        max_col1_width=$display_width
      fi
    else
      cleaned="$line"
    fi

    iterm_cleaned_lines+=("$cleaned")
    iterm_branches+=("$branch")
    iterm_is_current+=("$current")
    line_idx=$((line_idx + 1))
  done <<< "$gs_tree"

  col2_start=$((max_col1_width + 2))

  # -------------------------------------------------------------------------
  # Pass 2: Print with OSC 8 hyperlinks
  # -------------------------------------------------------------------------
  line_idx=0
  for cleaned in "${iterm_cleaned_lines[@]}"; do
    branch="${iterm_branches[$line_idx]}"
    current="${iterm_is_current[$line_idx]}"

    # Filtered branches are silently skipped (no placeholder)
    if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]] && ! branch_passes_filter "$branch" "$current"; then
      line_idx=$((line_idx + 1))
      continue
    fi

    if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
      title="${pr_title[$branch]}"
      url="${pr_url[$branch]}"

      # Prepend ⛔️ for closed/merged PRs
      closed_prefix=""
      if [[ "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ]]; then
        closed_prefix=$'\xe2\x9b\x94\xef\xb8\x8f '
      fi

      # Build OSC 8 hyperlink sequences using literal ESC bytes.
      # Using $'\e' avoids printf escape-sequence interactions that corrupt
      # the ST (String Terminator = ESC \) when embedded in format strings.
      osc_open=$'\e]8;;'"${url}"$'\e\\'
      osc_close=$'\e]8;;\e\\'

      if [[ "$SHOW_STATUS" -eq 1 ]]; then
        review="${pr_review[$branch]}"
        ci="${pr_ci[$branch]}"

        display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
        padding=$((col2_start - display_width))
        pad_str=$(printf '%*s' "$padding" '')

        # Link covers branch+title; emojis sit between tree prefix and title
        visible_text="${cleaned}${pad_str}${closed_prefix}${review}${ci}  ${title}"
      else
        display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
        padding=$((col2_start - display_width))
        pad_str=$(printf '%*s' "$padding" '')

        visible_text="${cleaned}${pad_str}${closed_prefix}${title}"
      fi

      if [[ "$current" -eq 1 ]]; then
        printf '%s%s%s%s%s\n' "$BOLD_YELLOW" "$osc_open" "$visible_text" "$osc_close" "$RESET"
      else
        printf '%s%s%s\n' "$osc_open" "$visible_text" "$osc_close"
      fi
    else
      # No PR data for this line (trunk, etc.)
      if [[ "$current" -eq 1 ]]; then
        printf '%s%s%s\n' "$BOLD_YELLOW" "$cleaned" "$RESET"
      else
        echo "$cleaned"
      fi
    fi

    line_idx=$((line_idx + 1))
  done

  # Legend
  if [[ "$SHOW_STATUS" -eq 1 ]]; then
    echo ""
    echo "Legend: [Review][CI] per line"
    printf '  \xf0\x9f\x9f\xa2 = approved / passing   \xf0\x9f\x94\xb4 = changes requested / failing\n'
    printf '  \xf0\x9f\x9f\xa1 = pending               \xe2\x9a\xaa = no checks\n'
  fi

  exit 0
fi

# ===========================================================================
# Output: Interactive format (original behavior)
# ===========================================================================

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
# Pass 2: Print with aligned columns (with filtering support)
# ---------------------------------------------------------------------------
line_idx=0
for cleaned in "${cleaned_lines[@]}"; do
  branch="${branches[$line_idx]}"
  current="${is_current[$line_idx]}"

  # Filtered branches are silently skipped (no placeholder)
  if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]] && ! branch_passes_filter "$branch" "$current"; then
    line_idx=$((line_idx + 1))
    continue
  fi

  if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
    title="${pr_title[$branch]}"
    url="${pr_url[$branch]}"

    # Prepend ⛔️ for closed/merged PRs when color is unavailable (fallback indicator)
    closed_prefix=""
    if [[ "$USE_COLOR" -eq 0 && ( "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ) ]]; then
      closed_prefix=$'\xe2\x9b\x94\xef\xb8\x8f '
    fi

    if [[ "$SHOW_STATUS" -eq 1 ]]; then
      review="${pr_review[$branch]}"
      ci="${pr_ci[$branch]}"

      # Compute padding to align column 2
      display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
      padding=$((col2_start - display_width))
      pad_str=$(printf '%*s' "$padding" '')

      # Build the output line: col1 + padding + emojis + title
      output_line="${cleaned}${pad_str}${closed_prefix}${review}${ci}  ${title}"
    else
      # No status — just show title after the tree
      display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
      padding=$((col2_start - display_width))
      pad_str=$(printf '%*s' "$padding" '')

      output_line="${cleaned}${pad_str}${closed_prefix}${title}"
    fi

    # Build the URL line with indentation aligned under the branch name
    prefix="${cleaned%%"$branch"*}"
    indent="${prefix//[^ ]/ }"
    url_line="${indent}${url}"

    if [[ "$current" -eq 1 ]]; then
      # Current branch: bold yellow highlighting (takes priority over closed/merged red)
      printf '%s%s%s\n' "$BOLD_YELLOW" "$output_line" "$RESET"
      printf '%s%s%s\n' "$BOLD_YELLOW" "$url_line" "$RESET"
    elif [[ "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ]]; then
      # Closed/merged PR: red text (when color available), ⛔️ already in output_line when not
      printf '%s%s%s\n' "$RED" "$output_line" "$RESET"
      printf '%s%s%s\n' "$RED" "$url_line" "$RESET"
    else
      echo "$output_line"
      echo "$url_line"
    fi
  else
    # No PR data for this line (trunk or untracked), print as-is
    if [[ "$current" -eq 1 ]]; then
      printf '%s%s%s\n' "$BOLD_YELLOW" "$cleaned" "$RESET"
    else
      echo "$cleaned"
    fi
  fi

  line_idx=$((line_idx + 1))
done

# ---------------------------------------------------------------------------
# Legend
# ---------------------------------------------------------------------------
if [[ "$SHOW_STATUS" -eq 1 ]]; then
  echo ""
  echo "Legend: [Review][CI] per line"
  printf '  \xf0\x9f\x9f\xa2 = approved / passing   \xf0\x9f\x94\xb4 = changes requested / failing\n'
  printf '  \xf0\x9f\x9f\xa1 = pending               \xe2\x9a\xaa = no checks\n'
fi
