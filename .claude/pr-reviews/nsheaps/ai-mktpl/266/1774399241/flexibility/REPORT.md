# Flexibility Review — PR #266

**Score: 72/100**

The plugin demonstrates strong design intentions around flexibility: configurable sources, an overridable cache directory, optional user-level sync, and a 3-tier config hierarchy. The recursive dependency system with cycle detection and a depth cap is a solid architectural choice that avoids both over-engineering (no graph solver needed) and brittleness (no infinite loops). However, several hardcoded assumptions limit real-world portability. The most significant is the unconditional hardcoding of GitHub as the only supported host — `clone_url` is always constructed as `https://github.com/${owner}/${repo}.git` with no option to target GitLab, Bitbucket, self-hosted Git, or private repositories via SSH or a token. The `read_source_config` function also duplicates the 3-tier config resolution logic that already exists in `shared/lib/plugin-config-read.sh`, but does so incompletely: it only searches for `.yaml`/`.yml` files and skips `.json`, whereas `plugin-config-read.sh` also handles JSON. This divergence will cause silent misconfiguration for users who prefer JSON settings files. The python3 regex fallback parser is fragile: it assumes exactly 2-space indentation for the `sources` key, meaning 4-space or tab-indented YAML will silently yield no sources without any error message. The `plugin_is_enabled` guard from the shared lib is never checked, so the plugin always runs even if someone sets `enabled: false` in their settings. The 60-second hook timeout is hardcoded in `hooks.json` and cannot be adjusted through config, which may be too short for slow network environments or too long for users who want faster session starts. On the positive side, the `cacheDir` override, `alsoSyncToUser` toggle, and the graceful handling of missing `yq` with a Python fallback all show thoughtful flexibility. The `read_source_config` function returning on the first non-empty file (line 345) also correctly preserves the project-over-user-over-plugin precedence, though it only merges to the first match rather than allowing additive sources across tiers — this is a design tradeoff that could surprise users who expect project sources to supplement rather than replace user-level sources.

## Inline Comments

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:113
`clone_url` is hardcoded to `https://github.com/`. There is no way to use GitLab, Bitbucket, self-hosted Git, or SSH URLs. A `host` or `cloneBaseUrl` config option, or a richer source ref format like `gitlab.com:owner/repo@ref:/path`, would make the plugin usable outside the GitHub ecosystem.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:113
Private repositories are not supported — there is no mechanism to inject credentials (e.g. a `GITHUB_TOKEN` or `gitCredential` config key). Any source in a private repository will silently fail with an authentication error from git, with only a generic "Failed to clone" message surfaced to the user.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:282-350
`read_source_config` reimplements the 3-tier settings file search instead of using `plugin_get_config_array`. The reimplementation omits `.json` file support (lines 286-293 only enumerate `.yaml`/`.yml` paths), so users with JSON-format settings files will get no sources loaded. The shared library already handles this correctly.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:345-349
Sources are taken from the **first** settings file that has a non-empty `sources` array and then the loop returns immediately. This means a project-level `plugins.settings.yaml` with `sources: []` would suppress all user-level sources, even though an empty array likely means "not configured here" rather than "intentionally empty". There is no documented behavior for this edge case.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:323-325
The python3 fallback parser assumes exactly 2-space indentation for the `sources:` key (`r'^\s{2}sources\s*:'`). YAML files using 4-space indentation or tabs will not match, causing silent failure — no sources will be loaded and no error will be emitted.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:355-362
The `plugin_is_enabled` check from `plugin-config-read.sh` is never called. A user who sets `enabled: false` in their settings will still have the hook run on every session start. Compare the mise plugin, which respects this flag.

### plugins/poc-shared-rules/hooks/hooks.json:12
The `timeout` of 60 seconds is hardcoded. Users with slow network connections or many deep dependency trees may hit this limit, while users who want snappier sessions cannot reduce it. A `hookTimeout` config key would allow per-project tuning.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:192
The `NOTE` comment on line 192 documents that the python3 fallback in `read_dependencies` only handles the legacy string format — mapping entries in `.shared-rules.yaml` require `yq`. This is a silent degradation: dependency files using the documented mapping format will have their dependencies silently skipped when `yq` is absent. This should either be surfaced as a warning or the fallback should be improved.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:39
`PROJECT_RULES_DIR` falls back to `./.claude/rules` when `CLAUDE_PROJECT_DIR` is unset. This relative path resolves against whatever the current working directory is at hook execution time, which may not be the project root. The mise plugin and others avoid this by requiring `CLAUDE_PROJECT_DIR` to be set or failing explicitly.
