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
#   - Branches in other worktrees prefixed with magenta "+ "
#   - Aligned columns for easy scanning
#
# Requirements: gs, gh, jq, python3
# Usage: gs-stack-status.sh [--output interactive|markdown|osc8] [--no-status]
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
TRUNCATE_BRANCH=35        # Default: truncate branch names to 35 chars
TRUNCATE_PR_TITLE=0       # Default: no PR title truncation (0 = disabled)
ONLY_REQUIRED_CI=1        # Default: CI status only reflects required checks
INCLUDE_CLOSED=0          # Default: hide closed/merged PRs

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --output requires a value (interactive or markdown)" >&2
        exit 1
      fi
      OUTPUT_FORMAT="$2"
      # Normalize aliases
      case "$OUTPUT_FORMAT" in
        iterm|kitty) OUTPUT_FORMAT="osc8" ;;
      esac
      if [[ "$OUTPUT_FORMAT" != "interactive" && "$OUTPUT_FORMAT" != "markdown" && "$OUTPUT_FORMAT" != "osc8" ]]; then
        echo "ERROR: --output must be 'interactive', 'markdown', or 'osc8' (aliases: iterm, kitty)" >&2
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
    --only-required-ci)
      ONLY_REQUIRED_CI=1
      shift
      ;;
    --no-only-required-ci)
      ONLY_REQUIRED_CI=0
      shift
      ;;
    --include-closed)
      INCLUDE_CLOSED=1
      shift
      ;;
    --no-include-closed)
      INCLUDE_CLOSED=0
      shift
      ;;
    --truncate-branch-length)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --truncate-branch-length requires a number" >&2
        exit 1
      fi
      TRUNCATE_BRANCH="$2"
      shift 2
      ;;
    --truncate-pr-title)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --truncate-pr-title requires a number" >&2
        exit 1
      fi
      TRUNCATE_PR_TITLE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: gs-stack-status.sh [--output interactive|markdown|osc8] [--no-status]"
      echo "       [--reviewed] [--no-reviewed] [--failing-ci] [--no-failing-ci]"
      echo "       [--color] [--no-color] [--watch [SECONDS]]"
      echo ""
      echo "Options:"
      echo "  --output FORMAT   Output format: interactive (default), markdown, or osc8 (aliases: iterm, kitty)"
      echo "  --no-status       Omit review/CI emoji indicators"
      echo "  --reviewed        Only show PRs that have been reviewed/approved"
      echo "  --no-reviewed     Only show PRs that have NOT been reviewed/approved"
      echo "  --failing-ci      Only show PRs where CI is failing"
      echo "  --no-failing-ci   Only show PRs where CI is NOT failing"
      echo "  --color           Force color output even when not a TTY"
      echo "  --no-color        Suppress color/escape codes even when on a TTY"
      echo "  --watch [SECS]    Refresh in-place every SECS seconds (default: 5)"
      echo "  --only-required-ci          CI status reflects only required checks (default)"
      echo "  --no-only-required-ci       CI status reflects all checks"
      echo "  --include-closed            Show closed/merged PRs (default: hidden)"
      echo "  --no-include-closed         Hide closed/merged PRs (default)"
      echo "  --truncate-branch-length N  Truncate branch names to N chars (default: 35)"
      echo "  --truncate-pr-title N       Truncate PR titles to N chars (default: no limit)"
      echo "  -h, --help        Show this help message"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option '$1'" >&2
      echo "Usage: gs-stack-status.sh [--output interactive|markdown|osc8] [--no-status] [--color] [--no-color] [--watch [SECS]]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Watch mode: re-invoke self in a loop using the alternate screen buffer.
# Uses alternate screen (like vim/less) to avoid polluting scrollback,
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

  # Use alternate screen buffer (like vim/less/htop) to avoid polluting
  # scrollback history, and hide cursor for cleaner display.
  cleanup() { printf '\033[?25h\033[?1049l'; }
  trap cleanup EXIT INT TERM
  printf '\033[?1049h\033[?25l'

  while true; do
    output=$("$0" "${child_args[@]}" 2>&1 || true)  # capture output
    printf '\033[H\033[J'                             # cursor home + clear to end
    printf '%s\n' "$output"                           # draw new content
    printf '\nLast updated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
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

# When --no-color is set and output is osc8, fall back to interactive mode
# since osc8 mode relies on escape codes for hyperlinks.
if [[ "$USE_COLOR" -eq 0 && "$OUTPUT_FORMAT" == "osc8" ]]; then
  OUTPUT_FORMAT="interactive"
fi

# Define color variables conditionally
if [[ "$USE_COLOR" -eq 1 ]]; then
  BOLD=$'\033[1m'
  BOLD_YELLOW=$'\033[1;33m'
  RED=$'\033[0;31m'
  BOLD_MAGENTA=$'\033[1;35m'
  RESET=$'\033[0m'
else
  BOLD=""
  BOLD_YELLOW=""
  RED=""
  BOLD_MAGENTA=""
  RESET=""
fi

# ---------------------------------------------------------------------------
# Emoji constants
# ---------------------------------------------------------------------------
EMOJI_GREEN=$'\xf0\x9f\x9f\xa2'    # 🟢
EMOJI_RED=$'\xf0\x9f\x94\xb4'      # 🔴
EMOJI_YELLOW=$'\xf0\x9f\x9f\xa1'   # 🟡
EMOJI_ORANGE=$'\xf0\x9f\x9f\xa0'   # 🟠
EMOJI_PURPLE=$'\xf0\x9f\x9f\xa3'   # 🟣
EMOJI_WHITE=$'\xe2\x9a\xaa'        # ⚪
EMOJI_RADIO=$'\xf0\x9f\x94\x98'    # 🔘
EMOJI_CLOSED=$'\xe2\x9b\x94\xef\xb8\x8f'  # ⛔️

# ---------------------------------------------------------------------------
# Truncation helper: truncate_str <string> <max_length>
# Returns the string truncated with "..." if longer than max_length.
# If max_length is 0, returns the string unchanged.
# ---------------------------------------------------------------------------
truncate_str() {
  local str="$1"
  local max="$2"
  if [[ "$max" -eq 0 ]] || [[ "${#str}" -le "$max" ]]; then
    printf '%s' "$str"
  else
    printf '%s...' "${str:0:$((max - 3))}"
  fi
}

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
  # Build the query per-PR (isRequired needs pullRequestNumber argument).
  query_body=""
  for number in "${!pr_number_to_branch[@]}"; do
    query_body="${query_body}
    pr${number}: pullRequest(number: ${number}) {
      reviewDecision
      isDraft
      state
      mergeStateStatus
      title
      url
      number
      headRefName
      commits(last: 1) {
        nodes {
          commit {
            statusCheckRollup {
              state
              contexts(first: 100) {
                nodes {
                  ... on CheckRun {
                    name
                    databaseId
                    status
                    conclusion
                    isRequired(pullRequestNumber: ${number})
                  }
                  ... on StatusContext {
                    context
                    cState: state
                  }
                }
              }
            }
          }
        }
      }
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
  # Process each PR alias from the response.
  # Review status now considers isDraft; CI status uses per-check context data
  # for granular states (running, running+failed, required-passed+optional-failed).
  lookup=$(echo "$graphql_result" | jq -r --argjson only_required "$ONLY_REQUIRED_CI" '
    .data.repository | to_entries[] |
    .value |

    # Review status from reviewDecision (APPROVED, CHANGES_REQUESTED,
    # REVIEW_REQUIRED, or null) combined with isDraft
    (if .isDraft then
      if .reviewDecision == "APPROVED" then "DRAFT_APPROVED"
      else "DRAFT"
      end
    elif .reviewDecision == "APPROVED" then "APPROVED"
    elif .reviewDecision == "CHANGES_REQUESTED" then "CHANGES_REQUESTED"
    else "UNREVIEWED"
    end) as $review |

    # mergeStateStatus: UNSTABLE = required passed but optional failed
    (.mergeStateStatus // "UNKNOWN") as $merge_state |

    # CI status: compute from per-check context data
    (
      (.commits.nodes[0].commit.statusCheckRollup // null) |
      if . == null then "NO_CI"
      else
        (.contexts.nodes // []) as $nodes |
        ($nodes | map(select(. != null))) as $all_valid |
        # Deduplicate: GitHub returns stale check runs from older workflow
        # re-runs alongside current ones. Group by name/context and keep
        # the entry with the highest databaseId (most recent).
        (
          # CheckRun nodes: deduplicate by name, keep highest databaseId
          ([$all_valid[] | select(.name != null)] |
            group_by(.name) |
            map(sort_by(.databaseId // 0) | last)
          ) +
          # StatusContext nodes: deduplicate by context, keep last
          ([$all_valid[] | select(.cState != null)] |
            group_by(.context) |
            map(last)
          )
        ) as $valid |
        if ($valid | length) == 0 then "NO_CI"
        else
          # When only_required=1, filter to only required CheckRun nodes
          # (StatusContext nodes have no isRequired, include them as-is)
          (if $only_required == 1 then
            $valid | map(select(
              (.isRequired == true) or (.cState != null)
            ))
          else $valid
          end) as $filtered |

          # CheckRun nodes: running if status exists and != COMPLETED
          ($filtered | map(select(
            .status != null and .status != "COMPLETED"
          )) | length) as $cr_running |
          # CheckRun nodes: failed conclusions
          ($filtered | map(select(
            .conclusion != null and
            (.conclusion | IN("FAILURE", "TIMED_OUT", "ERROR", "STARTUP_FAILURE", "ACTION_REQUIRED"))
          )) | length) as $cr_failed |
          # StatusContext nodes: running (PENDING/EXPECTED)
          ($filtered | map(select(
            .cState != null and (.cState | IN("PENDING", "EXPECTED"))
          )) | length) as $sc_running |
          # StatusContext nodes: failed
          ($filtered | map(select(
            .cState != null and (.cState | IN("FAILURE", "ERROR"))
          )) | length) as $sc_failed |

          (($cr_running + $sc_running) > 0) as $any_running |
          (($cr_failed + $sc_failed) > 0) as $any_failed |

          if $any_running and $any_failed then
            if $only_required == 1 then "CI_PENDING"
            else "CI_PENDING_FAIL"
            end
          elif $any_running then "CI_PENDING"
          elif $any_failed then
            if $only_required == 1 then "CI_FAIL"
            elif $merge_state == "UNSTABLE" then "CI_PARTIAL_FAIL"
            else "CI_FAIL"
            end
          else "CI_PASS"
          end
        end
      end
    ) as $ci |

    "\(.headRefName)\t\(.title)\t\($review)\t\($ci)\t\(.url)\t\(.state)"
  ')

  # Load lookup into associative arrays keyed by branch name
  while IFS=$'\t' read -r branch title review ci url state; do
    [[ -z "$branch" ]] && continue

    case "$review" in
      APPROVED)          review_emoji="$EMOJI_GREEN" ;;   # 🟢 approved
      CHANGES_REQUESTED) review_emoji="$EMOJI_RED" ;;     # 🔴 changes requested
      UNREVIEWED)        review_emoji="$EMOJI_YELLOW" ;;  # 🟡 open, unreviewed
      DRAFT)             review_emoji="$EMOJI_WHITE" ;;   # ⚪ draft
      DRAFT_APPROVED)    review_emoji="$EMOJI_RADIO" ;;   # 🔘 draft + approved
      *)                 review_emoji="$EMOJI_YELLOW" ;;  # 🟡 default to unreviewed
    esac
    case "$ci" in
      CI_PASS)         ci_emoji="$EMOJI_GREEN" ;;   # 🟢 all passing
      CI_FAIL)         ci_emoji="$EMOJI_RED" ;;     # 🔴 required checks failed
      CI_PENDING)      ci_emoji="$EMOJI_YELLOW" ;;  # 🟡 running, none failed
      CI_PENDING_FAIL) ci_emoji="$EMOJI_ORANGE" ;;  # 🟠 running + some failed
      CI_PARTIAL_FAIL) ci_emoji="$EMOJI_PURPLE" ;;  # 🟣 complete, required passed, optional failed
      NO_CI)           ci_emoji="$EMOJI_WHITE" ;;   # ⚪ no checks
      *)               ci_emoji="$EMOJI_YELLOW" ;;  # 🟡 default to pending
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
# Worktree detection: build a set of branches checked out in other worktrees
# ---------------------------------------------------------------------------
declare -A worktree_branches
current_worktree_dir=$(git rev-parse --show-toplevel 2>/dev/null || true)
while IFS= read -r wt_line; do
  # porcelain format: "worktree <path>" then "branch refs/heads/<name>"
  if [[ "$wt_line" == "worktree "* ]]; then
    wt_path="${wt_line#worktree }"
  elif [[ "$wt_line" == "branch refs/heads/"* ]]; then
    wt_branch="${wt_line#branch refs/heads/}"
    # Only mark branches in OTHER worktrees (not the current one)
    if [[ "$wt_path" != "$current_worktree_dir" ]]; then
      worktree_branches["$wt_branch"]=1
    fi
  fi
done < <(git worktree list --porcelain 2>/dev/null)

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

  # Filter closed/merged PRs unless --include-closed
  if [[ "$INCLUDE_CLOSED" -eq 0 ]]; then
    local state="${pr_state[$branch]:-}"
    if [[ "$state" == "CLOSED" || "$state" == "MERGED" ]]; then
      return 1
    fi
  fi

  # No other filters active — show everything
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
      title=$(truncate_str "${pr_title[$branch]}" "$TRUNCATE_PR_TITLE")
      url="${pr_url[$branch]}"
      pr_num="${branch_to_pr_number[$branch]}"

      closed_prefix=""
      if [[ "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ]]; then
        closed_prefix="${EMOJI_CLOSED} "
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
      if [[ "$current" -eq 1 ]]; then
        md_line="${indent}- **${branch}**"
      else
        md_line="${indent}- ${branch}"
      fi
    fi

    # Worktree indicator: insert "+ " before branch/link in the markdown line
    if [[ -n "${worktree_branches[$branch]+_}" ]]; then
      md_line="${md_line/- /- ＋ }"
    fi

    echo "$md_line"
  done <<< "$gs_tree"

  if [[ "$SHOW_STATUS" -eq 1 ]]; then
    echo ""
    printf '**%s/%s**\n' "$repo_owner" "$repo_name"
    printf 'Review: %s approved %s changes requested %s unreviewed %s draft %s draft+approved\n' \
      "$EMOJI_GREEN" "$EMOJI_RED" "$EMOJI_YELLOW" "$EMOJI_WHITE" "$EMOJI_RADIO"
    printf 'CI: %s passing %s required failed %s running %s running+failures %s optional failures %s no checks\n' \
      "$EMOJI_GREEN" "$EMOJI_RED" "$EMOJI_YELLOW" "$EMOJI_ORANGE" "$EMOJI_PURPLE" "$EMOJI_WHITE"
  fi

  exit 0
fi

# ===========================================================================
# Output: OSC 8 format (clickable hyperlinks for iTerm2, Kitty, etc.)
# ===========================================================================
# Uses OSC 8 escape codes to make branch+title a clickable hyperlink.
# Same tree structure as interactive mode but no separate URL line beneath.

if [[ "$OUTPUT_FORMAT" == "osc8" ]]; then
  max_col1_width=0
  max_pr_num_width=0
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
      cleaned=$(echo "$line" | sed -e 's| (https://[^)]*)||' -e 's| \[wt: [^]]*\]||')

      truncated_branch=$(truncate_str "$branch" "$TRUNCATE_BRANCH")
      if [[ "$truncated_branch" != "$branch" ]]; then
        cleaned="${cleaned/$branch/$truncated_branch}"
      fi

      # Insert worktree indicator before branch name
      if [[ -n "${worktree_branches[$branch]+_}" ]]; then
        cleaned="${cleaned/$truncated_branch/＋ $truncated_branch}"
      fi

      display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
      # Fullwidth ＋ is 2 columns but wc -m counts 1 char; correct for it
      [[ -n "${worktree_branches[$branch]+_}" ]] && (( display_width++ ))
      if (( display_width > max_col1_width )); then
        max_col1_width=$display_width
      fi

      pr_num="${branch_to_pr_number[$branch]}"
      pr_num_width=${#pr_num}
      if (( pr_num_width + 1 > max_pr_num_width )); then
        max_pr_num_width=$((pr_num_width + 1))
      fi
    else
      cleaned="$line"
      # Insert worktree indicator for branches without PRs
      if [[ -n "$branch" && -n "${worktree_branches[$branch]+_}" ]]; then
        cleaned=$(echo "$cleaned" | sed -e 's| \[wt: [^]]*\]||')
        cleaned="${cleaned/$branch/＋ $branch}"
      fi
    fi

    iterm_cleaned_lines+=("$cleaned")
    iterm_branches+=("$branch")
    iterm_is_current+=("$current")
    line_idx=$((line_idx + 1))
  done <<< "$gs_tree"

  col2_start=$((max_col1_width + 2))

  line_idx=0
  for cleaned in "${iterm_cleaned_lines[@]}"; do
    branch="${iterm_branches[$line_idx]}"
    current="${iterm_is_current[$line_idx]}"

    if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]] && ! branch_passes_filter "$branch" "$current"; then
      line_idx=$((line_idx + 1))
      continue
    fi

    if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
      title=$(truncate_str "${pr_title[$branch]}" "$TRUNCATE_PR_TITLE")
      url="${pr_url[$branch]}"
      pr_num="${branch_to_pr_number[$branch]}"

      closed_prefix=""
      if [[ "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ]]; then
        closed_prefix="${EMOJI_CLOSED} "
      fi

      osc_open=$'\e]8;;'"${url}"$'\e\\'
      osc_close=$'\e]8;;\e\\'

      display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
      [[ -n "${worktree_branches[$branch]+_}" ]] && (( display_width++ ))
      padding=$((col2_start - display_width))
      pad_str=$(printf '%*s' "$padding" '')
      pr_num_display=$(printf '%*s' "$max_pr_num_width" "#${pr_num}")

      if [[ "$SHOW_STATUS" -eq 1 ]]; then
        review="${pr_review[$branch]}"
        ci="${pr_ci[$branch]}"
        visible_text="${cleaned}${pad_str}${closed_prefix}${review}${ci} ${pr_num_display}  ${title}"
      else
        visible_text="${cleaned}${pad_str}${closed_prefix}${pr_num_display}  ${title}"
      fi

      # Colorize the worktree "+" indicator and branch name in bold magenta
      if [[ -n "${worktree_branches[$branch]+_}" ]]; then
        truncated_branch_osc=$(truncate_str "$branch" "$TRUNCATE_BRANCH")
        visible_text="${visible_text/＋ ${truncated_branch_osc}/${BOLD_MAGENTA}＋ ${truncated_branch_osc}${RESET}}"
      fi

      if [[ "$current" -eq 1 ]]; then
        printf '%s%s%s%s%s\n' "$BOLD_YELLOW" "$osc_open" "$visible_text" "$osc_close" "$RESET"
      else
        printf '%s%s%s\n' "$osc_open" "$visible_text" "$osc_close"
      fi
    else
      # Colorize the worktree "+" indicator and branch name in bold magenta
      if [[ -n "$branch" && -n "${worktree_branches[$branch]+_}" ]]; then
        cleaned="${cleaned/＋ ${branch}/${BOLD_MAGENTA}＋ ${branch}${RESET}}"
      fi

      if [[ "$current" -eq 1 ]]; then
        printf '%s%s%s\n' "$BOLD_YELLOW" "$cleaned" "$RESET"
      else
        echo "$cleaned"
      fi
    fi

    line_idx=$((line_idx + 1))
  done

  if [[ "$SHOW_STATUS" -eq 1 ]]; then
    echo ""
    repo_url="https://github.com/${repo_owner}/${repo_name}"
    osc_repo_open=$'\e]8;;'"${repo_url}"$'\e\\'
    osc_repo_close=$'\e]8;;\e\\'
    printf '%s%s%s/%s%s%s\n' "$BOLD" "$osc_repo_open" "$repo_owner" "$repo_name" "$osc_repo_close" "$RESET"
    printf '  Review: %s approved  %s changes requested  %s unreviewed  %s draft  %s draft+approved\n' \
      "$EMOJI_GREEN" "$EMOJI_RED" "$EMOJI_YELLOW" "$EMOJI_WHITE" "$EMOJI_RADIO"
    printf '  CI:     %s passing   %s required failed     %s running\n' \
      "$EMOJI_GREEN" "$EMOJI_RED" "$EMOJI_YELLOW"
    printf '          %s running+failures  %s optional failures  %s no checks\n' \
      "$EMOJI_ORANGE" "$EMOJI_PURPLE" "$EMOJI_WHITE"
  fi

  exit 0
fi

# ===========================================================================
# Output: Interactive format (original behavior)
# ===========================================================================

# ---------------------------------------------------------------------------
# Pass 1: Compute max width of column 1 (tree + branch) and max PR number width
# ---------------------------------------------------------------------------
max_col1_width=0
max_pr_num_width=0
declare -a cleaned_lines
declare -a branches
declare -a is_current

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
    cleaned=$(echo "$line" | sed -e 's| (https://[^)]*)||' -e 's| \[wt: [^]]*\]||')

    # Apply branch name truncation
    truncated_branch=$(truncate_str "$branch" "$TRUNCATE_BRANCH")
    if [[ "$truncated_branch" != "$branch" ]]; then
      cleaned="${cleaned/$branch/$truncated_branch}"
    fi

    # Insert worktree indicator before the branch name in the tree line
    if [[ -n "${worktree_branches[$branch]+_}" ]]; then
      cleaned="${cleaned/$truncated_branch/＋ $truncated_branch}"
    fi

    display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
    # Fullwidth ＋ is 2 columns but wc -m counts 1 char; correct for it
    [[ -n "${worktree_branches[$branch]+_}" ]] && (( display_width++ ))
    if (( display_width > max_col1_width )); then
      max_col1_width=$display_width
    fi

    # Track max PR number display width (e.g. "#15762" = 6)
    pr_num="${branch_to_pr_number[$branch]}"
    pr_num_width=${#pr_num}
    if (( pr_num_width + 1 > max_pr_num_width )); then  # +1 for "#"
      max_pr_num_width=$((pr_num_width + 1))
    fi
  else
    cleaned="$line"
    # Insert worktree indicator for branches without PRs
    if [[ -n "$branch" && -n "${worktree_branches[$branch]+_}" ]]; then
      cleaned=$(echo "$cleaned" | sed -e 's| \[wt: [^]]*\]||')
      cleaned="${cleaned/$branch/＋ $branch}"
    fi
  fi

  cleaned_lines+=("$cleaned")
  branches+=("$branch")
  is_current+=("$current")
  line_idx=$((line_idx + 1))
done <<< "$gs_tree"

col2_start=$((max_col1_width + 2))

# ---------------------------------------------------------------------------
# Pass 2: Print with aligned columns (with filtering support)
# ---------------------------------------------------------------------------
line_idx=0
for cleaned in "${cleaned_lines[@]}"; do
  branch="${branches[$line_idx]}"
  current="${is_current[$line_idx]}"

  if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]] && ! branch_passes_filter "$branch" "$current"; then
    line_idx=$((line_idx + 1))
    continue
  fi

  if [[ -n "$branch" && -n "${pr_title[$branch]+_}" ]]; then
    title=$(truncate_str "${pr_title[$branch]}" "$TRUNCATE_PR_TITLE")
    url="${pr_url[$branch]}"
    pr_num="${branch_to_pr_number[$branch]}"

    closed_prefix=""
    if [[ "$USE_COLOR" -eq 0 && ( "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ) ]]; then
      closed_prefix="${EMOJI_CLOSED} "
    fi

    # Pad column 1 (tree + branch)
    display_width=$(printf '%s' "$cleaned" | wc -m | tr -d ' ')
    [[ -n "${worktree_branches[$branch]+_}" ]] && (( display_width++ ))
    padding=$((col2_start - display_width))
    pad_str=$(printf '%*s' "$padding" '')

    # Right-align PR number within its column
    pr_num_display=$(printf '%*s' "$max_pr_num_width" "#${pr_num}")

    if [[ "$SHOW_STATUS" -eq 1 ]]; then
      review="${pr_review[$branch]}"
      ci="${pr_ci[$branch]}"
      output_line="${cleaned}${pad_str}${closed_prefix}${review}${ci} ${pr_num_display}  ${title}"
    else
      output_line="${cleaned}${pad_str}${closed_prefix}${pr_num_display}  ${title}"
    fi

    # URL line indented under the branch name
    # Use the truncated branch for prefix matching
    truncated_branch=$(truncate_str "$branch" "$TRUNCATE_BRANCH")
    prefix="${cleaned%%"$truncated_branch"*}"
    indent="${prefix//[^ ]/ }"
    url_line="${indent}${url}"

    # Colorize the worktree "+" indicator and branch name in bold magenta
    if [[ -n "${worktree_branches[$branch]+_}" ]]; then
      output_line="${output_line/＋ ${truncated_branch}/${BOLD_MAGENTA}＋ ${truncated_branch}${RESET}}"
    fi

    if [[ "$current" -eq 1 ]]; then
      printf '%s%s%s\n' "$BOLD_YELLOW" "$output_line" "$RESET"
      printf '%s%s%s\n' "$BOLD_YELLOW" "$url_line" "$RESET"
    elif [[ "${pr_state[$branch]}" == "CLOSED" || "${pr_state[$branch]}" == "MERGED" ]]; then
      printf '%s%s%s\n' "$RED" "$output_line" "$RESET"
      printf '%s%s%s\n' "$RED" "$url_line" "$RESET"
    else
      echo "$output_line"
      echo "$url_line"
    fi
  else
    # Colorize the worktree "+" indicator and branch name in bold magenta
    if [[ -n "$branch" && -n "${worktree_branches[$branch]+_}" ]]; then
      cleaned="${cleaned/＋ ${branch}/${BOLD_MAGENTA}＋ ${branch}${RESET}}"
    fi

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
  printf '%s%s/%s%s\n' "$BOLD" "$repo_owner" "$repo_name" "$RESET"
  printf '  Review: %s approved  %s changes requested  %s unreviewed  %s draft  %s draft+approved\n' \
    "$EMOJI_GREEN" "$EMOJI_RED" "$EMOJI_YELLOW" "$EMOJI_WHITE" "$EMOJI_RADIO"
  printf '  CI:     %s passing   %s required failed     %s running\n' \
    "$EMOJI_GREEN" "$EMOJI_RED" "$EMOJI_YELLOW"
  printf '          %s running+failures  %s optional failures  %s no checks\n' \
    "$EMOJI_ORANGE" "$EMOJI_PURPLE" "$EMOJI_WHITE"
fi
