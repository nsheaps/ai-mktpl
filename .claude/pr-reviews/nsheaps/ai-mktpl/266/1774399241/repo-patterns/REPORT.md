# Repo Patterns Review — PR #266

**Score: 90/100**

The `poc-shared-rules` plugin is a strong match for established repo patterns. The plugin directory structure is correct: it has `.claude-plugin/plugin.json`, `hooks/hooks.json`, `hooks/scripts/sync-rules.sh`, a `lib/` directory with the correct symlinks, a `README.md`, and a `<name>.settings.yaml`. All three required shared library symlinks are present and resolve correctly to `../../../shared/lib/` — `hook-logging.sh`, `log.sh`, and `plugin-config-read.sh` — matching the pattern in `common-sense` and `remote-config`. The hook script opens exactly as expected: `#!/usr/bin/env bash`, a descriptive comment block, `set -euo pipefail`, `PLUGIN_NAME` set before any `source` call, and `plugin-config-read.sh` sourced before `hook-logging.sh`. Config keys in `poc-shared-rules.settings.yaml` use camelCase (`alsoSyncToUser`, `cacheDir`) and are consistently referenced via `plugin_get_config "alsoSyncToUser"` and `plugin_get_config "cacheDir"` in the script, matching the settings-key-naming rule. The version `0.0.1` is correct for a new POC plugin. The `hooks.json` at `hooks/hooks.json` follows the external hooks file pattern — the hooks definition is not inlined in `plugin.json`, consistent with every other plugin in the repo (none of the established plugins include a `"hooks"` key in `plugin.json`; the rule's example of `{ "hooks": "./hooks/hooks.json" }` in `plugin.json` appears to be aspirational documentation not yet implemented in existing plugins, so not holding the PR to that standard). `hook_respond` is the last call before implicit exit, satisfying the contract. The `hook_log_cleanup` call before `hook_respond` is consistent with the `common-sense` hook script.

Two minor deductions: (1) The script calls `hook_fail` inside `fetch_into_cache` and `process_source`, then immediately does `return 1`, which with `set -euo pipefail` active will propagate upward through the call chain — this is safe only because the callers use `|| hook_log "WARNING: ..."` guards, but it means errors inside recursive `process_source` calls at depth > 0 are swallowed as warnings rather than surfaced via the structured error block. The established pattern (e.g., `common-sense`) uses `hook_run` to wrap the main function, which provides automatic error capture. (2) The `missing_plugin` for `poc-shared-rules` is absent from `marketplace.json` but this is expected per versioning rules for new plugins and is not a defect.

## Inline Comments

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:145-148
`hook_fail` logs a structured error to stderr, but the immediately following `return 1` propagates through `fetch_into_cache` back into `process_source` (line 249), which itself returns 1, and that is caught by the `|| hook_log "WARNING: ..."` guard on line 371. The structured `hook_fail` error block therefore fires but execution continues to `hook_respond` normally. This is functional but inconsistent with the intended pattern where `hook_run my_main_function` wraps the top-level call so that a single `hook_fail` maps cleanly to one structured error. Consider wrapping the main processing loop in a function and calling it via `hook_run`.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:361
`exit 0` is correctly placed inside the early-return branch (`if [ ${#SOURCES[@]} -eq 0 ]`). It is preceded by `hook_respond`, satisfying the "hook_respond MUST be last" contract for that branch. Good.

### plugins/poc-shared-rules/hooks/hooks.json:11
`"timeout": 60` is reasonable for a network operation (sparse clone). The `mise` plugin uses the same timeout for its install hook. Consistent.

### plugins/poc-shared-rules/.claude-plugin/plugin.json:1-13
No `"hooks"` key referencing `./hooks/hooks.json`. Per the plugin-hooks-organization rule, the correct pattern is `{ "hooks": "./hooks/hooks.json" }` in `plugin.json`. However, no existing plugin in the repo implements this key — `common-sense`, `mise`, `remote-config`, `context-bloat-prevention`, `github-app`, and `safety-evaluation-prompt` all omit it. This appears to be an unimplemented rule, so not penalized in the score, but worth noting for consistency if the rule is ever enforced.

### plugins/poc-shared-rules/lib/
The three symlinks present (`hook-logging.sh`, `log.sh`, `plugin-config-read.sh`) are the correct and sufficient set for this plugin's dependencies. Consistent with `common-sense` (minus `safe-settings-write.sh`, which this plugin does not need). No missing or spurious symlinks.
