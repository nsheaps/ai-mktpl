# Repo Patterns Review — PR #306
Score: 84/100

## Summary

The PR introduces async PR state tracking hooks to the github plugin and is largely well-aligned with existing repo patterns. The hooks.json format, double-source guard pattern in library files, settings YAML structure, and SKILL.md frontmatter all match established conventions. The most notable deviations are: the new hook scripts bypass the repo's `hook-logging.sh` / `hook_respond` / `hook_log_cleanup` infrastructure in favour of a lighter-weight approach using `log.sh` directly with plain `echo` output, and the new libraries live under `hooks/scripts/lib/` rather than the plugin-level `lib/` where shared shell libraries normally reside. One item from the PR description (a `lib/hook-output.sh` symlink) is listed as a change but does not appear on the branch at all, suggesting either an incomplete commit or stale description. These are genuine but non-blocking deviations from established patterns; nothing is broken, but the approach is inconsistent with how existing hooks are structured.

## Findings

### hooks.json format — MATCHES

The updated `plugins/github/hooks/hooks.json` follows the exact schema used by all other plugins: a top-level `description` string, a `hooks` object keyed by event name, each event containing an array of matcher objects with `matcher`, `hooks[]`, `type`, `command`, and `timeout` fields. The `matcher: "*"` wildcard is consistent with `plugins/mise/hooks/hooks.json` and `plugins/scm-utils/hooks/hooks.json`. Timeouts (30 s for SessionStart, 15 s for PostToolUse/Stop) are reasonable and distinct from the 60 s install hook, matching the convention of differentiating heavy vs. lightweight operations.

### Script structure — PARTIAL DEVIATION

Existing hook scripts (`install-gh.sh`, `install-mise.sh`) follow a strict pattern:
1. `PLUGIN_NAME="<name>"`
2. `source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"`
3. `source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"`
4. `source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"`
5. Guards using `plugin_is_enabled` and `tool_is_web_session` helper functions
6. A named `do_*` function wrapping all logic
7. `tool_run_install do_*` then `hook_log_cleanup` then `hook_respond` as the final exit sequence

The new `pr-state-check.sh` deviates from this in several ways:

- `plugins/github/hooks/scripts/pr-state-check.sh` line 3: sources `lib/log.sh` directly instead of `hook-logging.sh`, and uses bare `echo` to stdout for output rather than `hook_log` / `hook_respond`. The existing infrastructure accumulates messages in a temp file and emits them in a structured way via `hook_respond`; the new script bypasses this entirely.
- The guards use inline `command -v` checks and bare `exit 0` instead of `plugin_is_enabled` / `hook_log "... skipping"; hook_respond; exit 0` as seen in `install-gh.sh` lines 16–17.
- There is no `hook_log_cleanup` call at the end.
- The stdin consume (`hook_input="$(cat)"`) at line 48 is novel — existing hooks do not explicitly consume stdin. This is not wrong, but it is not a repo pattern; it is an introduced pattern. The comment says it avoids broken pipe, which is reasonable.

The new library files `hooks/scripts/lib/pr-state.sh` and `hooks/scripts/lib/pr-discover.sh` are placed under `hooks/scripts/lib/` rather than the plugin-level `plugins/github/lib/`. All existing shared shell libraries (`log.sh`, `hook-logging.sh`, `plugin-config-read.sh`, etc.) live in `plugins/<name>/lib/` and are symlinked identically across plugins. Putting hook-specific libraries one level deeper under `hooks/scripts/lib/` is a new sub-pattern not established elsewhere. It is internally consistent within this PR but diverges from the repo's convention of keeping all shell libraries at `lib/`.

### Double-source guard — MATCHES

Both new library files use the repo's established guard idiom:
```bash
if [ "${_PR_STATE_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_PR_STATE_LOADED="true"
```
This exactly matches the pattern in `plugins/github/lib/log.sh` (`_LOG_SH_LOADED`) and `plugins/github/lib/hook-logging.sh` (`_HOOK_LOGGING_LOADED`). The guard variable naming convention (`_<UPPER_NAME>_LOADED`) is consistent.

### Settings YAML — MATCHES

`plugins/github/github.settings.yaml` follows the existing pattern: a single top-level key matching the plugin name (`github:`), settings as indented scalar values, commented-out optional settings, and inline comments explaining each key. This matches `plugins/mise/mise.settings.yaml` structurally. The new keys (`prStateTracking`, `prStateCheckInterval`, `prStateCacheDir`) use the same camelCase convention as existing keys (`autoInstall`, `autoAuthCheck`, `backgroundInstall`).

### SKILL.md frontmatter and structure — MATCHES

`plugins/github/skills/pr-state-tracking/SKILL.md` uses the correct YAML frontmatter with `name:`, `description:` (multi-line `>` block), and `allowed-tools:` fields, matching the format of `plugins/github/skills/gh/SKILL.md` and `plugins/mise/skills/mise/SKILL.md`. The skill directory name matches the `name:` frontmatter field (`pr-state-tracking`). The document body uses H2 headings, code blocks, and a configuration table consistent with other skills.

### Missing lib/hook-output.sh symlink — INCONSISTENCY WITH PR DESCRIPTION

The PR description under "Changes" lists: `lib/hook-output.sh — Symlink to shared hook-output library`. However, on the PR branch (`a5e2afe`), `plugins/github/lib/` contains the same six files as on `main` — no `hook-output.sh` appears. The hook scripts reference `lib/log.sh` (which does exist) rather than any `hook-output.sh`. This is either a stale description item or an accidentally dropped commit. It is not a functional problem since the scripts work without it, but the PR description is misleading.

### Plugin.json and marketplace.json version bumps — MATCHES

Both `plugins/github/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` are bumped from `0.1.12` to `0.1.13`, consistent with the repo's semver patch increment convention for additive changes.

### hook_respond / stdout contract — DEVIATION

The existing contract (documented at length in `hook-logging.sh`) is that hooks must always `exit 0` and must call `hook_respond` exactly once as the last statement, which writes accumulated messages to stdout. `pr-state-check.sh` writes directly to stdout with `echo` and exits with bare `exit 0` without calling `hook_respond`. This works at the Claude hook runtime level, but it is not following the repo's established stdout/stderr separation contract. Specifically, the existing pattern ensures that stray `echo` calls from called functions cannot pollute hook output, by redirecting function stdout to stderr inside `hook_run`. The new script has no such protection.

## References

- `plugins/github/hooks/hooks.json` — base pattern for hooks.json schema
- `plugins/mise/hooks/hooks.json` — reference for SessionStart-only hook
- `plugins/scm-utils/hooks/hooks.json` — reference for Stop hook
- `plugins/github/hooks/scripts/install-gh.sh` — reference for hook script structure and guard pattern
- `plugins/mise/hooks/scripts/install-mise.sh` — reference for hook script structure
- `plugins/github/lib/hook-logging.sh` — defines `hook_respond`, `hook_log`, `hook_log_cleanup` contract
- `plugins/github/lib/log.sh` — double-source guard reference
- `plugins/github/github.settings.yaml` — settings YAML pattern
- `plugins/mise/mise.settings.yaml` — settings YAML pattern
- `plugins/github/skills/gh/SKILL.md` — SKILL.md frontmatter reference
- `plugins/github/skills/pr-state-tracking/SKILL.md` — new skill (PR branch)
- `plugins/github/hooks/scripts/pr-state-check.sh` — new entry point (PR branch)
- `plugins/github/hooks/scripts/lib/pr-state.sh` — new library (PR branch)
- `plugins/github/hooks/scripts/lib/pr-discover.sh` — new library (PR branch)
- https://github.com/nsheaps/ai-mktpl/pull/306
