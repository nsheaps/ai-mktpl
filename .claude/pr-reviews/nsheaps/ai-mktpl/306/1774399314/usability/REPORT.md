# Usability Review — PR #306

Score: 81/100

## Summary

This PR adds async PR state tracking hooks to the github plugin. The overall usability is strong: the feature is zero-config (enabled by default with sensible defaults), the change messages are specific and actionable, and the documentation is thorough across three locations (README, SKILL.md, and the settings YAML). The main usability gaps are a non-obvious dependency on `jq` that is silently swallowed, a PR discovery approach whose single-branch-per-repo constraint is undocumented from the user's perspective, a review comparison that only detects new reviews (not withdrawn or re-submitted ones), and the 60-second PostToolUse throttle creating a window where the agent could act on stale information.

## Findings

### Zero-config / works out of the box

`prStateTracking` defaults to `true` and the cache directory auto-resolves to `~/.claude/plugin-cache/github`. On first invocation the cache directory is created automatically. The feature requires `gh` and `jq` on PATH; both guards exit cleanly and silently if they are missing.

- `plugins/github/hooks/scripts/pr-state-check.sh` lines 38-50: both guards exit 0, which means the feature simply does nothing when requirements are missing. This is good for silent degradation, but there is no visible indication to the user that tracking is inactive because `jq` is absent. A one-time warning to the agent (e.g., written to the hook's stdout on first invocation only) would let users know what to install.

### Change notification quality

The messages are notably specific and actionable. Examples from `plugins/github/hooks/scripts/lib/pr-state.sh`:

- Line ~195: `"New review on ${owner}/${repo}#${pr_number}: ${review_line}"` — includes reviewer username and state (e.g., `nsheaps APPROVED`), immediately actionable.
- Line ~215: `"New comment on ${owner}/${repo}#${pr_number}: ${comment_line}"` — includes the first 100 characters of the comment body, enough context for the agent to decide whether to read more.
- Line ~227: `"New review comment on ${owner}/${repo}#${pr_number}: ${rc_line}"` — includes the file path and first 100 characters, aligning with the documented example `"nsheaps on src/main.ts: Consider using..."`.
- Lines ~244-252 (`_pr_state_diff_checks`): CI messages include the check name and the exact old/new status/conclusion transition, e.g., `"lint: in_progress/pending -> completed/success"`. This is better than a generic "CI changed" message.

**Gap — body change message is vague**: `"PR body updated on ${owner}/${repo}#${pr_number}"` (line ~162) reports that the body changed but provides no diff or summary. The agent knows something changed but must make another API call to learn what. All other change types surface at least the new value inline.

**Gap — review comparison is count-based only**: Lines 185-197 detect new reviews by comparing array length. If a reviewer dismisses and re-submits a review (same count, different state), or if a review is dismissed, the change is invisible. This is a latent correctness issue that may confuse agents when they see a stale APPROVED state after a CHANGES_REQUESTED dismissal.

**Gap — label message surfaces raw JSON**: Line ~179: `"Labels changed on ${owner}/${repo}#${pr_number}: ${old_labels} -> ${new_labels}"` where `${old_labels}` and `${new_labels}` are compact JSON arrays (e.g., `["bug","enhancement"]`). This is readable but inconsistent with the prose style of the other messages. Showing it as `bug, enhancement -> bug` would be cleaner.

### Configuration documentation

The settings file (`plugins/github/github.settings.yaml`) is the primary reference and is well-written. Each option has a multi-line comment explaining its purpose, units, defaults, and interaction with other options. The README has a full example YAML block and a separate subsection explaining the cache directory. The SKILL.md repeats the configuration in a condensed, skill-appropriate format.

- The `prStateCacheDir` option is commented out in the defaults file, which correctly signals "this is an override, not a required value".
- The 3-tier config resolution (plugin default → user level → project level) is mentioned in the README but not explicitly described as 3-tier; users who haven't read the broader plugin system docs might not know the precedence order.

### Graceful degradation

- Missing `gh`: exits 0 silently. Good.
- Missing `jq`: exits 0 silently. Good for non-interruption, but silent. Same concern as above.
- `CLAUDE_PROJECT_DIR` unset: falls back to `project_slug="default"`. Acceptable.
- No active PRs found: logs `"No active PRs found for tracked projects"` to the log (not to the agent's context window) and exits 0. Clean.
- `pr_state_fetch_and_compare` failure: returns 0 (treats as no-change). The API call returns `{}` on failure (line ~88 of pr-state.sh), which will then silently skip diffing. This is safe but means a transient API error could cause a missed change notification.

### PR discovery constraints (user comprehension)

`plugins/github/hooks/scripts/lib/pr-discover.sh` line 58 skips branches named `main` or `master` unconditionally. This is a reasonable heuristic to avoid tracking the base branch, but if a user's default branch is named `trunk` or `develop` it would be tracked (and likely find no PR). The README mentions multi-project discovery and the sibling-directory scan but does not mention the main/master exclusion or the single-open-PR-per-branch assumption. Users working on stacked PRs or repos with multiple open PRs from the same branch would only see one tracked.

The sibling directory scan has a usability implication that is undocumented: the plugin will also track PRs in any adjacent git repo under the parent directory, even repos unrelated to the current session. In a developer's home directory where multiple projects sit as siblings, this could produce surprising noise. The README acknowledges multi-project sessions positively but does not warn about this edge case.

### PostToolUse throttle and staleness

The 60-second default interval (`prStateCheckInterval`) means the agent could make decisions for up to a minute without seeing changes that arrived during that window. The output message `"Review these changes and determine if any action is needed."` (pr-state-check.sh, line ~141) is a useful prompt, but does not tell the agent how stale the information might be (i.e., when the last check actually ran). Adding a `"Last checked: <timestamp>"` line to the output would help the agent calibrate urgency.

### SessionStart output

On SessionStart with no changes, the script outputs `"github: PR state baseline established for ${pr_count} PR(s)"` to stdout. This is clear and confirms the feature is working. On subsequent PostToolUse runs with no changes, the script exits silently — good, no noise when nothing happens.

### Output format

The bulleted list format for changes is clean:

```
github: PR state changes detected since last check:

  - New review on owner/repo#123: nsheaps APPROVED
  - CI on owner/repo#123: lint: completed/pending -> completed/success

Review these changes and determine if any action is needed.
```

This is readable, correctly prefixed with the plugin name, and ends with an explicit action prompt. The trailing blank lines and the closing call-to-action improve agent comprehension over a raw list.

## References

- `plugins/github/hooks/scripts/pr-state-check.sh` — main hook entry point, guards, throttle logic, output formatting
- `plugins/github/hooks/scripts/lib/pr-state.sh` — fetch, cache, diff logic; change message construction
- `plugins/github/hooks/scripts/lib/pr-discover.sh` — multi-project PR discovery, branch filtering
- `plugins/github/github.settings.yaml` — config schema and inline documentation
- `plugins/github/README.md` — change detection table, cache structure, configuration examples
- `plugins/github/skills/pr-state-tracking/SKILL.md` — skill-level documentation, requirements, future roadmap
- `plugins/github/hooks/hooks.json` — hook registrations (SessionStart, PostToolUse, Stop)
- PR: https://github.com/nsheaps/ai-mktpl/pull/306
