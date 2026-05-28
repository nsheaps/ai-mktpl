# Best Practices Review — PR #306

Score: 62/100

## Summary

This PR introduces a well-structured async hook system for tracking PR state changes. The overall architecture (library separation, guard patterns, config tiers) reflects solid engineering thinking. However, several concrete shell scripting problems drag the score down: the `_pr_state_diff` function spawns ~20 subshells piping the same large JSON blob through `jq` one field at a time, which is both slow and fragile; cache writes are non-atomic, risking corrupt state on crash; the throttle file has a TOCTOU race; and a subtle operator-precedence bug in `pr-discover.sh` causes the main/master branch guard to always pass on non-`main` branches. Rate limiting is handled only by a coarse time gate with no backoff, and API failures silently produce empty strings rather than propagating errors.

---

## Findings

### F1 — CRITICAL: Operator-precedence logic bug in branch skip guard

**File:** `plugins/github/hooks/scripts/lib/pr-discover.sh`, line ~65

```bash
[ "$branch" = "main" ] || [ "$branch" = "master" ] && return 0
```

In bash, `&&` binds more tightly than `||` in the context of `[ ]` list operators. This line parses as:

```
[ "$branch" = "main" ]  OR  ([ "$branch" = "master" ] AND return 0)
```

So a branch named `main` does NOT trigger `return 0` — it falls through to the PR lookup. The intended check requires parenthesization:

```bash
{ [ "$branch" = "main" ] || [ "$branch" = "master" ]; } && return 0
```

or an `if` statement. As written, repos on `main` will generate spurious API calls every check cycle.

---

### F2 — HIGH: Non-atomic cache writes risk corrupt state

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, line ~56

```bash
echo "$new_state" > "$cache_file"
```

`echo … >` is a truncate-then-write, not atomic. If the process is killed mid-write (or if two hook invocations overlap — plausible given PostToolUse fires concurrently with tool activity), the cache file is left in a partial/empty state. On the next read, `old_state` would be empty, suppressing all change detection silently.

The standard fix is a write-then-rename pattern:

```bash
local tmp_file
tmp_file="$(mktemp "${cache_file}.XXXXXX")"
echo "$new_state" > "$tmp_file" && mv "$tmp_file" "$cache_file"
```

`mv` on the same filesystem is atomic. The same issue applies to the throttle timestamp file at `pr-state-check.sh` line ~83:

```bash
echo "$now" > "$last_check_file"
```

---

### F3 — HIGH: `_pr_state_diff` spawns ~20 subshells over the same JSON

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines ~130–260

Each field comparison does:

```bash
old_body="$(echo "$old" | jq -r '.pr.body // ""')"
new_body="$(echo "$new" | jq -r '.pr.body // ""')"
```

With ~10 compared fields, each requiring two `echo | jq` subshells, `_pr_state_diff` forks at minimum 20 processes per PR per invocation. On a slow system or when many PRs are tracked, this is a measurable performance issue. It also means the full JSON string (potentially large with long PR bodies) is passed through process substitution repeatedly.

The idiomatic approach is a single `jq` call that extracts all fields at once into shell variables via `read`:

```bash
read -r old_body old_title old_draft old_state … <<< \
  "$(echo "$old" | jq -r '[.pr.body // "", .pr.title // "", ...] | @tsv')"
```

Or, better: parse both old and new in a single `jq -n` invocation that emits all comparison results as a structured object, then parse that object once in shell. Either approach reduces 20+ forks to 1–2.

---

### F4 — HIGH: `_pr_state_diff_checks` is O(N²) in check count

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines ~265–295

For each check name in `all_checks`, the loop spawns 4 `echo "$old/$new" | jq` subshells:

```bash
old_status="$(echo "$old" | jq -r --arg name "$check_name" \
  '.checks.checks[] | select(.name == $name) | .status // "missing"' | head -1)"
```

If there are N checks, this is 4N subshells per diff call. Repos with many CI checks (20–50 is common) will make this very slow. The checks diff should be done in a single `jq` expression comparing both arrays together.

---

### F5 — MEDIUM: TOCTOU race in throttle timestamp

**File:** `plugins/github/hooks/scripts/pr-state-check.sh`, lines ~77–88

```bash
if [ -f "$last_check_file" ]; then
  last_check="$(cat "$last_check_file")"
  elapsed=$((now - last_check))
  if [ "$elapsed" -lt "$check_interval" ]; then
    exit 0
  fi
fi
echo "$now" > "$last_check_file"
```

There is a check-then-act gap between reading the file and writing the new timestamp. Two concurrent PostToolUse invocations can both read the same stale timestamp, both decide to proceed, and both fire simultaneous API batches. With `set -euo pipefail` active, this won't corrupt state, but it can cause double API calls. Using `ln` or `flock` would prevent this, but for a 60s throttle window this is low-severity in practice.

---

### F6 — MEDIUM: Unquoted variable expansion in `gh api` flag

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines ~85, ~91, ~96, etc.
**File:** `plugins/github/hooks/scripts/lib/pr-discover.sh`, line ~73

```bash
pr_json="$(gh api ${gh_hostname_flag} \
  "repos/${owner}/${repo}/pulls/${pr_number}" …)"
```

`${gh_hostname_flag}` is unquoted. When empty, this expands correctly, but when set to `--hostname github.com` it relies on word splitting to pass two arguments. This is an accidental correct use of unquoted expansion. The idiomatic approach is an array:

```bash
local -a gh_flags=()
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  gh_flags=(--hostname github.com)
fi
gh api "${gh_flags[@]}" "repos/…"
```

This is more robust and passes `shellcheck`.

---

### F7 — MEDIUM: API rate limits not handled; no exponential backoff

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines ~80–115

Each `_pr_state_fetch` call makes 4–5 sequential API requests (PR, reviews, comments, review comments, check-runs). With multiple PRs across multiple projects, a session could easily generate 20+ requests per check cycle. There is no handling of HTTP 429 / rate-limit responses — `gh api` will print an error to stderr (suppressed by `2>/dev/null`) and fall back to empty strings or `[]`, meaning the cache is overwritten with incomplete data and legitimate changes are silently dropped.

At minimum, the fetch should log a warning rather than silently discarding rate-limit errors. A better approach: check `gh api --include` for a `Retry-After` header or `X-RateLimit-Remaining` and back off.

---

### F8 — MEDIUM: `cat > /dev/null` idiom for stdin drain is misleading

**File:** `plugins/github/hooks/scripts/pr-state-check.sh`, lines ~36–44

```bash
if [ "$pr_state_enabled" = "false" ]; then
  cat > /dev/null
  exit 0
fi
```

The early-exit guards drain stdin before exiting using `cat > /dev/null`. This is functionally correct but semantically odd — it looks like a typo. The intent (consuming stdin to avoid SIGPIPE) is not documented at these guard sites. The stdin drain at line ~72 is documented but the guard drains are not. Either add a comment or refactor the drain into a function called `_drain_stdin` for clarity.

---

### F9 — LOW: Global mutable variables used as return values in sourced library

**File:** `plugins/github/hooks/scripts/lib/pr-discover.sh`, lines ~78–82

```bash
_PR_OWNER=""
_PR_REPO=""
```

`_pr_extract_owner_repo` communicates results via global variables. This works but is fragile in sourced-library contexts: any caller that sources this file gets these globals in its namespace. Because `pr-state.sh` also sources `pr-discover.sh` transitively, these globals are shared across both libraries. The pattern is common in bash but makes the API implicit. A `nameref` (bash 4.3+) or stdout-with-parsing would be more explicit.

---

### F10 — LOW: `jq` labels filter has incorrect array comprehension

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, line ~192

```bash
old_labels="$(echo "$old" | jq -c '[.pr.labels // [] | sort[]]')"
```

`sort[]` is not valid jq for sorting an array and iterating. The correct idiom is `(.pr.labels // []) | sort` then wrapping. The actual expression `[.pr.labels // [] | sort[]]` works in practice because jq's `[]` after `sort` iterates and `[…]` re-collects, but the expression is confusing and may not behave as expected if `labels` is already an array of strings (it is). The more readable and unambiguous form is:

```bash
jq -c '[(.pr.labels // []) | sort[]]'
# or
jq -c '(.pr.labels // []) | sort'
```

---

### F11 — LOW: No pagination on API calls for comments/reviews

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines ~91–101

`gh api` without `--paginate` returns at most the first page (typically 30 items). For PRs with many comments or reviews, only the first page is fetched. This means new items added before a page boundary are never surfaced. Since this is a change-detection system, missed events are a correctness problem. The fix is either `--paginate` (returns all pages but costs more API calls) or accept the limitation and document it.

---

### F12 — LOW: `PLUGIN_NAME` variable is declared but never used

**File:** `plugins/github/hooks/scripts/pr-state-check.sh`, line ~18

```bash
PLUGIN_NAME="github"
```

This variable is set at the top of `pr-state-check.sh` but never referenced. Dead code.

---

## References

- Files reviewed:
  - `plugins/github/hooks/scripts/pr-state-check.sh`
  - `plugins/github/hooks/scripts/lib/pr-state.sh`
  - `plugins/github/hooks/scripts/lib/pr-discover.sh`
  - `plugins/github/hooks/hooks.json`
- https://github.com/nsheaps/ai-mktpl/pull/306
- Shell scripting references:
  - [Bash Pitfalls — Greg's Wiki](https://mywiki.wooledge.org/BashPitfalls)
  - [ShellCheck](https://www.shellcheck.net/) — F6 (unquoted flag var) and F1 (operator precedence) are detectable by shellcheck
  - [Bash FAQ: Atomic file writes](https://mywiki.wooledge.org/AtomicWriting)
  - [GitHub REST API — Rate Limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
