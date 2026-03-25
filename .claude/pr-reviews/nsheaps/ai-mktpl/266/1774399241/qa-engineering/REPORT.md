# QA & Engineering Practices Review — PR #266

**Score: 62/100**

This PR introduces a well-structured new plugin (`poc-shared-rules`) with a clear purpose and reasonably solid implementation. Validation passes cleanly (`mise run validate`), the PR description is accurate and thorough, version `0.0.1` is appropriate for a POC, and most commit messages follow conventional commits. However, the branch has significant engineering discipline issues that drag the score down considerably. The commit history is noisy and polluted: 20 commits for a single new plugin, with 5 standalone lint-pass commits (`chore: \`mise run lint\``, `chore: \`just lint\``) that should have been squashed into the preceding fix commits. One commit explicitly violates the project's CRITICAL rule by using `[skip ci]`in a manually-authored agent commit — the`ci-cd/conventions.md`rule states "NEVER use [skip ci]… in manual commits" and explicitly calls out AI agents as subject to this rule. There is also one commit with a non-conventional message ("Update .claude/plugins.settings.yaml"). On the testing side, the test plan is entirely manual with no automated tests or validation scripts, which is partly acceptable for a bash hook plugin, but even a simple smoke-test script or bats test would meaningfully raise confidence. The plugin.json is also missing the`"hooks": "./hooks/hooks.json"`reference required by the`plugin-hooks-organization.md`rule — the hooks file exists in`hooks/hooks.json` but is not wired up via the manifest, which is a structural violation. The PR correctly marks itself as a draft POC, addresses prior review feedback, and its description is well-written and accurate to the actual changes, which are positive signals.

## Inline Comments

### plugins/poc-shared-rules/.claude-plugin/plugin.json:1

`plugin.json` is missing the `"hooks": "./hooks/hooks.json"` field required by the `plugin-hooks-organization.md` convention. The `hooks/hooks.json` file exists but is not referenced from the manifest. This may cause the hook to not be registered when the plugin is installed.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:113

`clone_url` is hardcoded to `https://github.com/${owner}/${repo}.git`. If the plugin is ever used with non-GitHub sources (GitLab, self-hosted), this silently fails with a confusing error. A comment or config option clarifying GitHub-only support would prevent user confusion.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:345

`read_source_config` returns exit code 1 when no config file is found, but the caller at line 356 uses `|| true` to suppress it. This means a missing config file and an empty sources array are treated identically — there's no way to distinguish "no config file at all" from "config file exists but sources is empty". This could silently swallow misconfiguration errors.

### commit: 6b4b88c

`chore: prettier formatting for deny array in settings.json [skip ci]` — this is a direct violation of `ci-cd/conventions.md` CRITICAL rule: "NEVER use [skip ci]… If you are a human or an AI agent pushing code, CI must always run." This commit was authored by the Claude agent, not an automated CD workflow, so `[skip ci]` is prohibited here.

### commit: 0b82f06

"Update .claude/plugins.settings.yaml" does not follow conventional commit format. Should be `chore: update plugins.settings.yaml` or similar with a descriptive scope.

### commit history (general)

Five separate lint-pass commits (`chore: \`mise run lint\``, `chore: \`just lint\``) appear as standalone commits rather than being squashed into the preceding fix/chore they accompanied. This inflates the commit count to 20 for what is effectively a single new plugin addition and makes `git log` harder to read. These should be squashed before merge.
