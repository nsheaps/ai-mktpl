# Best Practices Review — PR #266

**Score: 82/100**

The script is well-structured overall and adheres to most of the conventions in `shared-libs.md`. `set -euo pipefail` is present at the top, `PLUGIN_NAME` is set before any library is sourced, `hook_respond` is called exactly once as the last statement (both in the early-exit path at line 360–362 and at the final line 376), and the script always exits 0 (no explicit `exit 1` is ever reached by the main flow — `hook_fail` returns 0 and the callers use `|| hook_log` guards). Variable quoting is thorough throughout. `local` is used consistently for function-scoped variables. The use of `hook_log` / `hook_log_step` / `hook_fail` instead of raw `echo` is correct and follows the shared-libs conventions.

The deductions are:

1. **Global mutation of `parse_source_ref` output vars is a hidden coupling risk (lines 54–58, 234–253).** The function writes to `_SRC_OWNER`, `_SRC_REPO`, `_SRC_PATH`, `_SRC_REF`, `_SRC_NAME` as plain globals rather than local variables or a nameref output parameter. Because `set -euo pipefail` is active, any subshell that calls `parse_source_ref` would silently lose those values. It also makes the function impossible to call safely from a subshell context. The pattern is functional here because callers are in the same shell, but it is fragile and undocumented.

2. **`read_source_config` returns exit code 1 when no sources are found (line 350), causing the `readarray` on line 356 to behave unexpectedly under `set -e`.** The `|| true` on line 356 saves the immediate error, but the function's non-zero exit on "no config found" is a semantic mismatch: it means "I found nothing" but is indistinguishable from "I encountered an error". The caller cannot distinguish the two cases.

3. **`CACHE_BASE` is a global that is used directly in `get_cache_dir` (line 104) without being passed as an argument.** This is an undeclared dependency that makes `get_cache_dir` non-self-contained. The same applies to `PROJECT_RULES_DIR`, `USER_RULES_DIR`, `ALSO_SYNC_TO_USER`, and `VISITED_FILE` inside `process_source`. While globals are idiomatic in bash, they should be documented at the point of declaration.

4. **Idempotency is partial but not complete.** Re-running the script when a symlink already exists removes and re-creates the symlink (line 171–172), which is correct. However, if the target cache directory's `.git` is present but corrupted, the `git -C "$cache_dir" checkout ... || true` chain silently succeeds with a stale checkout (lines 121–129). There is no validation that the sparse-checkout actually materialised the expected path before proceeding. The `[ ! -d "$rules_path" ]` check on line 254 provides a safety net, but only after the fact.

5. **`hook_log_step` is called once per source (line 244) without any corresponding "step done" marker.** The `hook-logging.sh` step API expects a single named step to describe a block of work; calling it repeatedly in a loop with different step names is semantically correct but means each iteration opens a new step. This is not a bug, but reviewers should be aware the log will show N steps for N sources.

6. **The inline Python heredocs (lines 203–218, 302–342) are functional but use regex-based YAML parsing as a fallback.** This is explicitly noted as limited in the comments, but there is no `hook_fail` or warning when neither `yq` nor `python3` is available (the function just produces no output). If both tools are absent the hook silently processes zero sources, which looks like "no sources configured" rather than "parsing unavailable". A `hook_log "WARNING: neither yq nor python3 available — cannot parse sources"` branch would improve observability.

7. **Minor: `local file key="${PLUGIN_NAME}"` on line 283 declares two variables in one statement.** While syntactically valid in bash, mixing declaration and assignment across multiple variables in a single `local` call is error-prone (`local a=1 b=2` is fine, but `local a b=$()` silently hides a non-zero subshell exit under `set -e`). Here both values are simple strings so there is no immediate bug, but it is contrary to the style established elsewhere in the file.

## Inline Comments

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:51–94

`parse_source_ref` sets module-level globals (`_SRC_*`) as its output mechanism. This is an undocumented side-effecting pattern. Add a comment block at the function definition explaining that callers must read `_SRC_*` immediately after the call and that the function must never be invoked from a subshell.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:104

`get_cache_dir` silently depends on the global `CACHE_BASE`. A comment or a third parameter would make this dependency explicit.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:119

```bash
git -C "$cache_dir" fetch origin --depth=1 2>/dev/null || true
```

The outer `if !` already provides a fallback; the inner `|| true` means a network failure during the fallback fetch is silently swallowed. The script will then proceed to `checkout FETCH_HEAD`, which may use a stale ref without warning.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:197–219

If neither `yq` nor `python3` is available, `read_dependencies` returns silently with no output and no warning. This causes dependencies to be silently skipped, which is hard to debug. Add an `else` branch with `hook_log "WARNING: neither yq nor python3 found — dependency file ${deps_file} will be ignored"`.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:283

`local file key="${PLUGIN_NAME}"` — split into two `local` declarations: `local file` and `local key="${PLUGIN_NAME}"`. Mixing multi-variable local declarations with assignments is a readability and safety concern.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:299–343

If neither `yq` nor `python3` is available, `read_source_config` produces no output and returns 1. The caller at line 356 catches the exit via `|| true`, but zero sources being found versus zero sources being parseable is indistinguishable. Add a warning when neither parser is available:

```bash
else
  hook_log "WARNING: neither yq nor python3 available — cannot parse source config in ${file}"
fi
```

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:350

`return 1` when no sources are found conflates "no config present" with "an error occurred". Consider `return 0` with an empty output, or document the convention explicitly so callers can distinguish these cases.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:356

```bash
readarray -t SOURCES < <(read_source_config || true)
```

`SOURCES` is a global array. Under `set -euo pipefail`, unset array variables accessed with `${#SOURCES[@]}` are safe (they expand to 0), but if the intent is to treat an empty array as "no sources", the `read_source_config || true` swallows genuine errors. A two-step approach — capture output, then check — would be clearer.
