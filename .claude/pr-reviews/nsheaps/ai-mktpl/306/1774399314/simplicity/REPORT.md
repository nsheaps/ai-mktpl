# Simplicity Review — PR #306
Score: 58/100

## Summary

The PR introduces a real, useful feature — async PR state tracking — and the overall intent is clean: fetch, cache, diff, report. However, the implementation carries a meaningful complexity tax at several layers. The `_pr_state_diff` function spawns a separate `echo "$json" | jq` subprocess for every individual field it inspects (roughly 20 separate jq invocations against the same two JSON blobs), when a single jq call could produce all diff output at once. The 3-file library split is slightly over-engineered for the volume of code involved: `pr-discover.sh` (114 lines) and `pr-state.sh` (330 lines) are reasonable in isolation, but their combined caller `pr-state-check.sh` is thin enough (145 lines, much of which is scaffolding) that collapsing all three into a single well-commented script would reduce sourcing overhead and make the execution path easier to follow. The `PostToolUse "*"` matcher with an in-script throttle works correctly but introduces a subtle ordering constraint: the throttle state file is written *after* the interval check passes, meaning the script must always spin up just to re-read the cache and exit — a more targeted matcher or a dedicated debounce hook type would eliminate that per-tool-use bash invocation entirely. These are real costs but none are blockers; the code is correct and well-commented throughout.

## Findings

### 1. `_pr_state_diff`: ~20 redundant jq subprocesses (high impact)

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines 152–285

The function compares old and new state by calling `echo "$old" | jq -r '...'` and `echo "$new" | jq -r '...'` once per field, in sequence. Counting the individual subshell invocations:

- body: 2 jq calls
- title: 2
- draft: 2
- state + merged: 4
- mergeable + mergeable_state: 4
- labels: 2
- review count: 2 (plus a conditional third for new review text)
- comment count: 2 (plus conditional)
- review comment count: 2 (plus conditional)
- CI checks comparison: 2 (plus `_pr_state_diff_checks` which spawns N additional calls per check name)

That is roughly 22–30 forks just for the diff of a single PR. Each call re-parses the same JSON string. A single jq invocation can compare all scalar fields and produce structured output:

```bash
jq -r -n \
  --argjson old "$old" \
  --argjson new "$new" \
  '{
    body_changed: ($old.pr.body != $new.pr.body),
    title_changed: ($old.pr.title != $new.pr.title),
    old_title: $old.pr.title,
    new_title: $new.pr.title,
    draft_changed: ($old.pr.draft != $new.pr.draft),
    new_draft: $new.pr.draft,
    state_changed: ($old.pr.state != $new.pr.state),
    ...
  } | to_entries[] | select(.value == true or (.key | endswith("_changed") | not)) | ...'
```

This would cut subprocess count from ~25 to 1–2, with real performance impact since the function runs on every throttle-passing PostToolUse event across multiple PRs.

### 2. `_pr_state_diff_checks`: N jq subprocesses per check name (high impact)

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines 288–323

The function first calls jq once to get all check names, then for each check name spawns 4 more jq calls (old_status, old_conclusion, new_status, new_conclusion). For a repo with 10 CI checks this is 41 jq invocations for a single diff. This entire function could be replaced with a single jq call that joins old and new check arrays by name and emits only the changed rows:

```bash
jq -r -n \
  --argjson old "$(echo "$old" | jq '.checks.checks // []')" \
  --argjson new "$(echo "$new" | jq '.checks.checks // []')" \
  '($old | map({(.name): {status,conclusion}}) | add // {}) as $om |
   ($new | map({(.name): {status,conclusion}}) | add // {}) as $nm |
   ([$old[].name, $new[].name] | unique[]) as $name |
   select($om[$name] != $nm[$name]) |
   "\($name): \($om[$name].status // "missing")/\($om[$name].conclusion // "pending") -> \($nm[$name].status // "missing")/\($nm[$name].conclusion // "pending")"'
```

This reduces the check diff from O(N×4)+1 calls to 3 (two to extract subfields before passing `--argjson`, or 1 if old/new are passed as top-level objects).

### 3. 3-file library split is slightly over-engineered for the code volume

**Files:** `pr-state-check.sh` (145 lines), `pr-state.sh` (330 lines), `pr-discover.sh` (114 lines)

The split is principled — orchestration vs. state-fetch/diff vs. discovery — and would be appropriate if each library were reused independently. However, `pr-discover.sh` is sourced only by `pr-state-check.sh`, and `pr-state.sh` is sourced only by `pr-state-check.sh`. With no other consumers, the indirection adds `source` overhead and reader navigation cost without reuse benefit. Collapsing all three into a single `pr-state-check.sh` with internal `_` prefixed functions (following the pattern already used) would make the execution path linear and self-contained, reducing cognitive overhead from ~590 lines across 3 files to one cohesive script.

The split is not wrong and is forward-compatible if reuse is anticipated, but there is no current evidence of that intent.

### 4. `PostToolUse "*"` matcher launches a bash process on every tool call

**File:** `plugins/github/hooks/hooks.json`, line 14

The matcher `"*"` means `pr-state-check.sh` is invoked after every single tool use. The script then reads the throttle file to decide whether to exit early. This is correct behavior, but it means the full bash startup + `source` of 4 library files + config reads occurs on every tool use — only to exit after the interval check in most cases. A more efficient approach would be to place the throttle check *before* the library sources, or to use a dedicated hook event that fires less frequently if the platform supports it. Currently the early-exit guard at line 98 in `pr-state-check.sh` comes after config reads, `source` calls, and guard checks — which is already reasonably fast but not minimal.

A minor structural improvement: move the `hook_input="$(cat)"` stdin drain above the throttle check, which is already required before any early exit to avoid breaking the pipe, but the current ordering already does this correctly.

### 5. Global mutation via `_PR_OWNER` / `_PR_REPO` in `pr-discover.sh`

**File:** `plugins/github/hooks/scripts/lib/pr-discover.sh`, lines 72–74

`_pr_extract_owner_repo` communicates its results by setting module-level global variables `_PR_OWNER` and `_PR_REPO`. In a sourced library this is a surprising side effect. The function could instead echo `owner repo` to stdout and be called as `read -r owner repo < <(_pr_extract_owner_repo "$url")`, which is idiomatic shell and eliminates the global state. This is a minor style issue but adds to complexity when reasoning about the library.

### 6. `cat > /dev/null` pattern for stdin drain on early exit

**File:** `plugins/github/hooks/scripts/pr-state-check.sh`, lines 48, 52, 56

Each early-exit guard uses `cat > /dev/null` before `exit 0` to drain stdin. This pattern is correct for Claude Code hooks (which pipe stdin), but:
- The `hook_input="$(cat)"` drain at line 82 already handles this once stdin is needed.
- The early-exit guards before any stdin read are correct to drain, but `cat > /dev/null` is an unusual idiom. The simpler `exec > /dev/null 2>&1` or `read -r -d '' _` would be more standard. This is a minor clarity issue, not a correctness problem.

### 7. `pr_state_changes_summary` is defined but never called

**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines 325–335

The function `pr_state_changes_summary` provides a formatted summary of `PR_STATE_CHANGES`, but `pr-state-check.sh` iterates the array directly to build its own output. The summary function is dead code in the current implementation. Either the function should be used by the caller, or it should be removed. Its presence adds a small navigation burden without benefit.

### 8. `[ "$branch" = "main" ] || [ "$branch" = "master" ]` filtering in discover

**File:** `plugins/github/hooks/scripts/lib/pr-discover.sh`, line 63

Filtering out `main` and `master` as a proxy for "no PR open" is a reasonable heuristic but not correct in all cases: some workflows use `main` or `master` as feature branches, and some repos use different default branch names (e.g., `trunk`, `develop`). The correct check — which the code already performs two lines later — is to query the API for an open PR and get an empty result. The branch-name filter is an unnecessary pre-check that adds fragility. Removing it simplifies the function to just "try to find a PR; if none, return 0."

## References

- `plugins/github/hooks/scripts/lib/pr-state.sh` — `_pr_state_diff` (lines 152–285), `_pr_state_diff_checks` (lines 288–323)
- `plugins/github/hooks/scripts/lib/pr-discover.sh` — `_pr_extract_owner_repo` (lines 72–114), branch filter (line 63)
- `plugins/github/hooks/scripts/pr-state-check.sh` — PostToolUse throttle (lines 98–109), early-exit guards (lines 46–56)
- `plugins/github/hooks/hooks.json` — PostToolUse `"*"` matcher (line 14)
- PR #306: https://github.com/nsheaps/ai-mktpl/pull/306
