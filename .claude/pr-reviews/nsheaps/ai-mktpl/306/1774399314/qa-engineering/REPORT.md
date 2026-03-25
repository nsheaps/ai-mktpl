# QA & Engineering Review — PR #306
Score: 47/100

## Summary

This PR adds async hook infrastructure for PR state tracking in the github plugin. The core idea is sound and the implementation is thorough in documentation, but at time of review the PR had seven open review threads — all of which were addressed in a subsequent fix commit (`862fbafeb43ca0ff9c63bafdf22b3b8540f74767`). However, the PR body was never updated to remove the stale `lib/hook-output.sh` entry from the Changes section, and the branch has a `mergeable_state` of "dirty" (requires rebase against main). There are no automated tests for any of the new shell scripts, and the test plan consists entirely of manual verification steps with no evidence of execution. The 5 sequential `gh` API calls per PR have no partial-failure recovery, meaning a single transient network failure mid-fetch results in silently stale cache state. The PostToolUse hook's `*` matcher fires on every tool use, addressed only by a timestamp throttle — not a targeted matcher — which could still cause rate-limit pressure in active sessions.

## Findings

### 1. PR Body Inaccuracy — Stale File Reference
The Changes section of the PR body still lists:
> `lib/hook-output.sh` — Symlink to shared hook-output library

This file was removed in commit `862fbafeb` per the "Remove unused hook-output.sh symlink (YAGNI)" fix. The PR body was never updated to reflect this removal. The file does not appear in any changed-files listing, confirming it is absent from the final branch state. The test plan and summary sections are otherwise accurate.

### 2. Dirty Merge State — Rebase Required
`mergeable_state: "dirty"` at head SHA `a5e2afe8dd87220f2c3685bcd3edb5ac5f09c0b3`. The branch needs a rebase onto `main` before merge. Since the PR is still draft, this is expected but must be resolved before promotion.

### 3. No Automated Tests
Zero test files exist for any of the three new shell scripts:
- `plugins/github/hooks/scripts/pr-state-check.sh`
- `plugins/github/hooks/scripts/lib/pr-state.sh`
- `plugins/github/hooks/scripts/lib/pr-discover.sh`

The test plan is 7 manual checkbox items, none marked as completed. There is no bats, shellspec, or similar framework invocation. CI passes only `lint` and `validate` checks — neither exercises the new functionality. Given that the core logic (JSON diffing, cache file management, throttle state, multi-repo discovery) is all testable in isolation, the absence of tests is a significant gap for production reliability.

### 4. Partial-Failure State Corruption in `_pr_state_fetch`
`plugins/github/hooks/scripts/lib/pr-state.sh` (lines ~85–155) makes 5 sequential `gh api` calls. The failure handling is asymmetric:

- Call 1 (PR core data): `|| { echo "{}" ; return 1; }` — returns 1, and the caller (`pr_state_fetch_and_compare`) traps this with `|| return 0`, so no cache write occurs. This is correct.
- Calls 2–4 (reviews, comments, review comments): `|| review_json="[]"` / `|| comment_json="[]"` / `|| review_comment_json="[]"` — silently substitutes empty arrays on failure and continues.
- Call 5 (check runs): `|| checks_json='{"total_count":0,"checks":[]}'` — same pattern.

The problem: if call 1 succeeds but call 2 (reviews) fails transiently, the function continues with `review_json="[]"`, combines all state into JSON, and **writes the incomplete snapshot to the cache file**. On the next invocation, the old (complete) cache is replaced by the new (incomplete) one. The diff logic then reports "all reviews disappeared" — generating false-positive change notifications — or worse, silently misses real changes because the baseline is now wrong.

A correct approach would either:
- Track whether any secondary call failed and skip the cache write, or
- Record a `fetch_error` flag in the JSON to suppress diffs for that invocation.

### 5. Uncaught Failure Modes: `jq` Combining Step
After all 5 API calls, the function runs a `jq -n` to combine results (pr-state.sh, ~lines 157–170). This step has no `||` guard. If `jq` fails (e.g., malformed JSON from one of the `|| fallback` paths), the function exits non-zero, but `pr_state_fetch_and_compare` has already passed the point where it guards on fetch failure. Depending on bash `set -e` propagation through sourced libs, this may silently exit the entire hook rather than returning a controlled error.

### 6. Comment Count Diffing — Assumes Append-Only
`plugins/github/hooks/scripts/lib/pr-state.sh` (lines ~210–240) detects new reviews, comments, and review comments by comparing array lengths and slicing from `[$old_count:]`. This assumes comments are only ever added, never deleted. If a comment is deleted externally (GitHub allows this), the new count may be lower, the slice index becomes negative or out-of-range, and `jq` emits nothing — the deletion is silently ignored with no notification. The current implementation explicitly does not detect deletions.

### 7. Review Deduplication Not Handled
The reviews diff (pr-state.sh ~lines 195–210) compares total review count. GitHub's reviews endpoint returns a full history including superseded reviews (e.g., a reviewer who approved, then requested changes, then approved again will appear 3 times). Count-based diffing will report a new review event even if the reviewer merely re-submitted the same state, and will miss review state _changes_ within the same reviewer's review record if no new review object is appended.

### 8. Shell Logic Bug: Operator Precedence in Branch Skip
`plugins/github/hooks/scripts/lib/pr-discover.sh` (line ~63):
```bash
[ "$branch" = "main" ] || [ "$branch" = "master" ] && return 0
```
Due to bash's left-to-right evaluation with equal precedence for `||` and `&&`, this parses as:
```bash
([ "$branch" = "main" ]) || ([ "$branch" = "master" ] && return 0)
```
If `branch` is `main`, the first test is true, the `||` short-circuits, and `return 0` is NOT executed — the function continues processing the main branch as if it had a PR. The fix commit (`862fbafeb`) does not appear to have addressed this. The correct form is:
```bash
{ [ "$branch" = "main" ] || [ "$branch" = "master" ]; } && return 0
```

### 9. Unquoted Variable in `gh api` Call
`plugins/github/hooks/scripts/lib/pr-discover.sh` (line ~75) and `pr-state.sh` (lines ~90, ~100, etc.):
```bash
gh api ${gh_hostname_flag} \
```
`${gh_hostname_flag}` is unquoted. When empty, this is fine. When set to `--hostname github.com`, it expands to two words correctly. However, with `set -u` active (via `set -euo pipefail` in `pr-state-check.sh`), if `gh_hostname_flag` were ever unset (not just empty) this would error. The variable is always initialized to `""` so this is low risk but is a style violation under `set -u` conventions.

### 10. PostToolUse Timeout May Be Too Short
`plugins/github/hooks/hooks.json` (line 27): PostToolUse timeout is 15 seconds. With 5 sequential API calls per PR (each with network latency), a multi-repo session tracking 3 PRs could require 15+ API calls. On a slow network or GitHub API slowdown, the hook will time out mid-fetch, leaving partial state. The throttle ensures this doesn't happen every tool call, but the first execution after the 60s window may still exceed 15s for multi-PR sessions.

### 11. CI Status: All Checks Pass
- `lint`: completed/success
- `validate`: completed/success
- `auto-version-bump`: completed/success
- `bump-and-update-marketplace`: skipped (expected for draft)
- `claude-review`: skipped (expected for draft)

No CI failures. The lint check validates the new shell scripts pass shellcheck (implicitly, given the lint job passes).

### 12. Commit Quality
The 5 commits on the branch are:
1. `e1c5f3ab` — `feat(github): add async hooks for PR state tracking` — well-scoped initial implementation
2. `35642ca6` — `chore: mise run lint` — atomic, appropriate
3. `8f7ca2f9` — `chore: auto-bump plugin versions and update marketplace` — automation bot, appropriate
4. `121d91b2` — merged commit from PR #300 (mise fix + scm-utils rename) — **this commit is unrelated to the PR's stated purpose** and includes work from a separate PR; it is a history artifact from rebasing/squashing
5. `862fbafeb` — `fix(github): address PR review feedback on async hooks` — addresses 6 of 7 review threads; well-described

Commit 4 is the most notable: it includes the mise absolute-path fix and the auto-pr-to-making-great-prs rename, both of which are logically separate features. This inflates the PR's diff and makes the history harder to bisect.

### 13. Open Review Threads Not All Resolved
Of the 7 original review threads from `henry-nsheaps`:
- Threads marked `is_outdated: true` (5 of 7): addressed in the fix commit and superseded by code changes
- `hooks.json` PostToolUse matcher thread: `is_outdated: false`, **not resolved** — the throttle was added, but the `*` matcher remains; the thread author's suggestion to use a targeted matcher was not implemented
- `README.md` tilde expansion thread: `is_outdated: false`, **not resolved** — tilde expansion was added to the script (`pr-state-check.sh:52`) but the thread was not marked resolved

### 14. Test Plan Gaps
The test plan does not cover:
- Behavior when `gh` API returns an error mid-sequence (partial fetch)
- Comment/review deletion handling
- The `main`/`master` branch skip logic
- Behavior with repos that have no remote or a non-GitHub remote
- Rate limit handling (HTTP 403/429 from `gh`)
- Cache file corruption or invalid JSON in cache
- The `$ARGUMENTS`-less path in `/fix-pr` command (unrelated but included in this PR)

## References

- PR: https://github.com/nsheaps/ai-mktpl/pull/306
- Head commit: https://github.com/nsheaps/ai-mktpl/commit/a5e2afe8dd87220f2c3685bcd3edb5ac5f09c0b3
- Fix commit (review feedback): https://github.com/nsheaps/ai-mktpl/commit/862fbafeb43ca0ff9c63bafdf22b3b8540f74767
- `pr-state.sh`: `plugins/github/hooks/scripts/lib/pr-state.sh`
- `pr-discover.sh`: `plugins/github/hooks/scripts/lib/pr-discover.sh`
- `pr-state-check.sh`: `plugins/github/hooks/scripts/pr-state-check.sh`
- `hooks.json`: `plugins/github/hooks/hooks.json`
- Open review thread (PostToolUse matcher): https://github.com/nsheaps/ai-mktpl/pull/306#discussion_r2983942600
- Open review thread (tilde expansion): https://github.com/nsheaps/ai-mktpl/pull/306#discussion_r2983944156
