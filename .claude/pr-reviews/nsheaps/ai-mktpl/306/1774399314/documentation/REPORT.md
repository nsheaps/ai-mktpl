# Documentation Review — PR #306
Score: 87/100

## Summary

The documentation for this PR is thorough and well-structured across all layers. Shell scripts have clear file-level headers with purpose, usage, environment variable, and return value documentation. The README and SKILL.md are comprehensive, accurate, and complementary without being redundant. The settings YAML is exceptionally well-commented — arguably the best-documented file in the set. The PR body is clearly written but contains one stale reference to `lib/hook-output.sh`, a file that was removed during the review feedback cycle. There are minor discoverability gaps and a few inline comment accuracy issues that keep this from being a near-perfect documentation score.

## Findings

### Shell Script Headers and Function Documentation

**pr-state-check.sh** (lines 1–18): Header clearly states purpose, the three hook events it serves, and all relevant environment variables (`HOOK_EVENT`, `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`). The `set -euo pipefail` declaration is visible and unambiguous. No issues.

**pr-state.sh** (lines 1–15): Header documents purpose, usage pattern (source + init + fetch_and_compare), return value semantics (`0`/`1`), and the array side-effect (`PR_STATE_CHANGES`). Requirements section lists `gh` and `jq` explicitly. Function-level comments follow consistently throughout the file. One minor note: `_pr_state_diff_checks` (line 296) documents its output as "human-readable diff lines via stdout" but does not mention that it emits nothing when there are no changes — callers have to infer this from the surrounding code.

**pr-discover.sh** (lines 1–9): Header is correct and succinct. The guard-against-double-sourcing pattern and the global `_PR_OWNER`/`_PR_REPO` side-effect variables are both noted inline. The note on the internal output variables (lines 75–77) is a helpful contract signal for maintainers.

One inline comment accuracy issue: `pr-discover.sh` line 61 comments `[ "$branch" = "main" ] || [ "$branch" = "master" ] && return 0` — this is documented as "skip default branches" but the bash operator precedence here means only `master` is guarded by the `&&`. The `main` check is a standalone condition that always returns 0 if the branch is `main`. The logic works by accident (both OR branches evaluate before `&&` in practice for simple string comparisons) but the comment does not flag this fragility, and a reader relying on the comment alone could be misled.

### README.md

The README is the strongest documentation artifact in this PR. It:

- Adds a clear `### GitHub CLI Installation` section header to separate the existing feature from the new one (previously the "How It Works" section jumped directly into numbered steps with no subheading).
- Provides a complete change-detection table with real-world example values.
- Correctly describes the three hook events and their throttle behavior.
- Accurately documents the cache path structure including the `/<project-slug>/pr-state/` suffix appended by the plugin.
- The "Future: Claude Code Channels" section is clearly marked as speculative (`> **Planned feature**`) and does not overstate what the current code does.
- The `## Local Sessions` section is updated to note that PR state tracking runs on both local and web sessions, which matches the actual script behavior.

Minor gap: The README does not document what happens when `CLAUDE_PROJECT_DIR` is unset (the script falls back to `project_slug="default"`). This edge case is handled gracefully in code but is invisible to users reading the docs.

### SKILL.md

The skill file is well-suited for consumption by AI agents. The frontmatter `description` field is concise and trigger-word-rich, appropriate for skill matching. The body covers all hook events, configuration keys with defaults, cache structure, requirements, and the future channels roadmap. Content is accurate and consistent with both the README and the implementation.

The one structural gap: SKILL.md documents `prStateCacheDir: ""` (empty string as the shown default), while the README shows it commented-out with the actual default path as a comment. These are technically consistent (empty string means "use default") but a reader comparing the two docs could be confused about whether to set the key at all.

### github.settings.yaml

The settings file is the most thoroughly commented in the diff. The `--- PR State Tracking ---` block header, inline description of what the feature does, the throttle/debounce semantics note on `prStateCheckInterval`, the path-suffix clarification on `prStateCacheDir`, and the `~`/`$HOME` support note are all present and accurate. The commented-out `prStateCacheDir` key with its suggested structure is a good affordance. No issues.

### Inline Comment Accuracy

Beyond the `pr-discover.sh` operator-precedence issue noted above, all other inline comments are accurate. The comment in `pr-state.sh` at line 82 ("Note: reviewDecision is only available via GraphQL, not REST API") is a genuinely useful caveat for future maintainers. The throttle section comment in `pr-state-check.sh` (lines 71–74) correctly describes both the mechanism and the exceptions (SessionStart/Stop always run).

### PR Body / Description

The PR body is well-written: the summary bullet list accurately describes the feature, the changes table is complete and maps to real files, and the test plan checkboxes are specific and actionable.

**Stale reference (confirmed defect)**: The Changes section lists `lib/hook-output.sh — Symlink to shared hook-output library` as a changed file. Inspecting the branch (`a5e2afe`), `plugins/github/lib/` contains `add-permission.sh`, `hook-logging.sh`, `log.sh`, `plugin-config-read.sh`, `safe-settings-write.sh`, and `tool-install.sh` — there is no `hook-output.sh` present. The file diff also shows no such entry. This entry was removed from the implementation following review feedback but was never removed from the PR body. It should be deleted from the Changes list.

### Discoverability

The plugin's `plugin.json` and `marketplace.json` keywords were expanded to include `pr-state-tracking`, `ci-status`, `reviews`, `async-hooks`, and `multi-project` — good for search-based discovery. The README feature list bullet is visible near the top of the document.

One gap: there is no mention in the README of the `SKILL.md` file or the `skills/pr-state-tracking/` directory. Users browsing the README would not know the skill document exists. A one-line pointer under `## Skills` (e.g., "See `skills/pr-state-tracking/SKILL.md` for full agent-facing documentation") would close this.

A secondary discoverability concern: the `prStateTracking: true` default means the feature is on by default for all users of this plugin, but the README only notes how to disable it in the context of project-specific overrides, not as a standalone "to opt out, set `prStateTracking: false`" statement. New users may not realize the feature is running.

## References

- PR: https://github.com/nsheaps/ai-mktpl/pull/306
- `plugins/github/README.md` — https://github.com/nsheaps/ai-mktpl/blob/claude/github-async-hooks-1z1aZ/plugins/github/README.md
- `plugins/github/skills/pr-state-tracking/SKILL.md` — https://github.com/nsheaps/ai-mktpl/blob/claude/github-async-hooks-1z1aZ/plugins/github/skills/pr-state-tracking/SKILL.md
- `plugins/github/github.settings.yaml` — https://github.com/nsheaps/ai-mktpl/blob/claude/github-async-hooks-1z1aZ/plugins/github/github.settings.yaml
- `plugins/github/hooks/scripts/pr-state-check.sh` — https://github.com/nsheaps/ai-mktpl/blob/claude/github-async-hooks-1z1aZ/plugins/github/hooks/scripts/pr-state-check.sh
- `plugins/github/hooks/scripts/lib/pr-state.sh` — https://github.com/nsheaps/ai-mktpl/blob/claude/github-async-hooks-1z1aZ/plugins/github/hooks/scripts/lib/pr-state.sh
- `plugins/github/hooks/scripts/lib/pr-discover.sh` — https://github.com/nsheaps/ai-mktpl/blob/claude/github-async-hooks-1z1aZ/plugins/github/hooks/scripts/lib/pr-discover.sh
