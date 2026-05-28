# Flexibility Review — PR #306

Score: 78/100

## Summary

This PR is well-designed for flexibility across its primary use cases. The three-setting configuration surface (enable/disable, interval, cache directory), combined with environment-adaptive behavior and thoughtful graceful degradation, gives users meaningful control without requiring code changes. The library separation between `pr-state.sh` and `pr-discover.sh` makes the feature modular and extensible. The score is held back by a small set of hardwired behaviors that cannot be overridden via config — notably the sibling-directory discovery strategy, the GitHub-only remote assumption, and the absence of any per-PR or per-repo filtering controls. These are not architectural flaws but rather gaps that will likely surface as soon as the feature is adopted at scale.

## Findings

### Strengths

**1. Clean enable/disable with silent exit**
`pr-state-check.sh` lines 32–37 check `prStateTracking: false` and exit 0 immediately, consuming stdin to avoid a broken pipe. This is the correct pattern for a no-op hook — the agent never sees noise from a disabled feature.

**2. Configurable throttle interval**
`prStateCheckInterval` (default 60s) is read from plugin config and applied to PostToolUse via a `.last-check` timestamp file (`pr-state-check.sh` lines 71–82). SessionStart and Stop bypass the throttle, which is the right behavior: baseline must always establish, and the final check on Stop should always run. Users needing a quieter experience can push this to 300 or higher in their `plugins.settings.yaml` without touching any script.

**3. Three-tier cache directory resolution**
`pr-state-check.sh` lines 47–62 implement a clean fallback chain: user-configured `prStateCacheDir` > `$HOME/.claude/plugin-cache/github`. Tilde and `$HOME` are both expanded. The project slug appended from `CLAUDE_PROJECT_DIR` ensures multiple projects never collide in a shared cache base. This is flexible enough for shared-home environments and project-specific overrides alike.

**4. Environment-adaptive gh flag**
Both `pr-state.sh` and `pr-discover.sh` check `CLAUDE_CODE_REMOTE` and conditionally apply `--hostname github.com` to all `gh api` calls. This transparently handles the web session proxy-remote pattern without any user configuration required.

**5. Graceful degradation for missing dependencies**
`pr-state-check.sh` lines 39–48 guard against missing `gh` or `jq` with silent exits. `_pr_discover_for_dir` uses `|| return 0` at every fallible step (git branch, remote URL, PR lookup). `_pr_state_fetch` falls back to `"{}"` and `"[]"` on API errors. The feature fails open — no output is worse than crashing the hook.

**6. Multi-project sibling discovery is automatic**
`pr-discover.sh` scans `$(dirname CLAUDE_PROJECT_DIR)/*/` for `.git` directories and adds them without requiring the user to enumerate repos. This zero-config multi-project support is a genuine flexibility win for the primary target environment (Claude Code web sessions with co-cloned repos).

**7. Library architecture supports extension**
The split between `pr-state.sh` (fetch/cache/diff) and `pr-discover.sh` (enumerate repos) allows either to be extended or replaced independently. The `PR_STATE_CHANGES` array is a clean, inspectable output contract. A future channels integration would only need to replace the output section of `pr-state-check.sh` — the detection engine is already reusable.

**8. Channels future-proofing is explicitly documented**
`README.md` and `SKILL.md` both document the planned channels integration pattern. The architectural note that "state diffs would become channel triggers" gives any future contributor a clear upgrade path without requiring a rewrite.

---

### Limitations and Gaps

**1. Discovery strategy is not configurable — no way to opt in to strict single-project mode**
`pr-discover.sh:pr_discover_all` always scans sibling directories when `CLAUDE_PROJECT_DIR` is set. There is no config key to say "only track the primary project" or "track these specific repos." In a dense home directory where many sibling folders happen to be git repos, this can produce a large and unintended PR list. A `prStateDiscoveryMode: auto|primary-only` or `prStateAdditionalDirs` config key would address this.

**2. Default-on with no per-project override hint in the settings file**
`github.settings.yaml` sets `prStateTracking: true` as the default and comments out `prStateCacheDir`. The README documents project-level override correctly, but there is no example of turning off tracking for a specific project only (e.g., `prStateTracking: false` in a project's `.claude/plugins.settings.yaml`). Users inheriting this at the user level may not realize they can override it per project.

**3. Branch filter is hardcoded to skip `main` and `master` only**
`pr-discover.sh` line 63: `[ "$branch" = "main" ] || [ "$branch" = "master" ] && return 0`. Repositories using `develop`, `trunk`, or a different default branch name will still emit a lookup attempt for that branch, burning an API call and potentially returning unexpected results if an old PR exists for it. There is no `prStateDefaultBranch` config or a `gh repo view --json defaultBranchRef` lookup to detect the actual default branch.

**4. `_PR_OWNER` and `_PR_REPO` are global variables set by side effect**
`pr-discover.sh` lines 80–81 declare `_PR_OWNER=""` and `_PR_REPO=""` at script scope, written by `_pr_extract_owner_repo`. If `pr_discover_all` is ever called concurrently or sourced in a context with subshells, these globals are not safe. More importantly, if the function is ever tested or reused, the caller must know to read `_PR_OWNER`/`_PR_REPO` rather than a return value. A local output-via-stdout or nameref pattern would be more flexible.

**5. PostToolUse timeout is 15 seconds, but the fetch makes 4–5 sequential API calls per PR**
`hooks.json` sets `"timeout": 15` for PostToolUse. `_pr_state_fetch` makes up to 5 sequential `gh api` calls (PR metadata, reviews, issue comments, review comments, check runs). On a session tracking 3–4 PRs across multiple repos, this can exceed 15 seconds on a slow connection. There is no `prStateFetchTimeout` config. The user has no way to tune the per-hook timeout without editing `hooks.json` directly.

**6. No mechanism to exclude specific PRs or repos from tracking**
Once a sibling repo is discovered and has an open PR on the current branch, it is always tracked. There is no deny-list (`prStateIgnoreRepos`) or allow-list (`prStateTrackRepos`) config. A user who has a long-running draft PR in a sibling repo they are not actively working on will receive repeated "no changes" noise (or worse, frequent change notifications for unrelated work).

**7. Cache invalidation has no TTL or manual clear mechanism**
Cache files grow indefinitely and are never pruned. A PR that is merged and its cache file never cleaned up will be re-compared on the next session if the branch is somehow recreated. There is no `prStateCacheMaxAge` config or a documented `rm -rf ~/.claude/plugin-cache/github/<slug>/pr-state/` step in the README.

**8. GitHub-only; no GitLab or Bitbucket support path**
`_pr_extract_owner_repo` explicitly matches `github.com` or the web session proxy format and returns 1 for all other remotes. This is fine for the current scope, but there is no abstraction layer (e.g., a `pr-provider.sh` interface) that would allow a non-GitHub remote to be supported without rewriting the discovery and fetch logic. Given the plugin is named "github" this is expected, but it is a ceiling worth noting.

---

### Minor Observations

- `pr-state-check.sh` line 66 reads stdin into `hook_input` but never uses it. This is correct (stdin must be consumed) but the variable assignment creates a mild confusion — a comment explaining why the value is intentionally discarded would help.
- The `pr_state_changes_summary` function in `pr-state.sh` (lines 310–320) is defined but never called from the main entry point, which instead formats its own output inline. The function is available for future use but is dead code today.
- The `all_checks` variable in `_pr_state_diff_checks` is populated via `<<<` here-string from `jq -r ... unique[]`. If `jq` returns an empty string (no checks), the `while` loop receives one empty line and the `[ -z "$check_name" ] && continue` guard on line 281 handles it. The guard is correct but the empty-string-from-heredoc edge case is non-obvious.

## References

- `plugins/github/hooks/scripts/pr-state-check.sh` — main entry point, config reading, throttle logic
- `plugins/github/hooks/scripts/lib/pr-state.sh` — fetch, cache, and diff engine
- `plugins/github/hooks/scripts/lib/pr-discover.sh` — multi-project PR enumeration
- `plugins/github/hooks/hooks.json` — hook registration and timeouts
- `plugins/github/github.settings.yaml` — config key definitions and defaults
- `plugins/github/README.md` — user-facing documentation including channels roadmap
- `plugins/github/skills/pr-state-tracking/SKILL.md` — skill-level documentation
- PR: https://github.com/nsheaps/ai-mktpl/pull/306
