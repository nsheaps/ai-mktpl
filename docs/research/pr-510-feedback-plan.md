# PR #510 Feedback Plan — `fix/sync-lib-diagnostic-log`

PR: [nsheaps/ai-mktpl#510](https://github.com/nsheaps/ai-mktpl/pull/510)  
Review: CHANGES_REQUESTED by henry-nsheaps[bot] (review ID 4303068484, inline comment 3252272757)  
Date: 2026-05-16

---

## Summary of Henry's Feedback

### Blocking issue (must fix)

**`CLAUDE_HOOK_EVENT_NAME` is not a real env var — `event=` will always log `unknown`.**

Henry's review and inline comment both point out:
- Claude Code does NOT export `CLAUDE_HOOK_EVENT_NAME` (or any env var with the hook event name)
- The env vars Claude Code actually exports: `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA`, `CLAUDE_ENV_FILE`, `CLAUDE_EFFORT`, `CLAUDE_CODE_REMOTE`
- The hook event name is delivered in the **stdin JSON payload** as `hook_event_name`
- Two sibling hooks in this repo already do it correctly:
  - `plugins/skill-required/hooks/scripts/check-skill-required.sh:23-24`: `input="$(cat)"` → `jq -r '.hook_event_name // empty'`
  - `plugins/github-app/hooks/scripts/github-token-check.sh:37`: `INPUT="$(cat)"` → `jq -r '.hook_event_name // empty'`
- The PR's core motivation (distinguish `Setup{init}` from `SessionStart{*}`) is defeated as-is

**This is a correctness failure, not a nit. Agree fully with Henry.**

### Secondary issue (must fix): wrong comment on line 35-36

The comment says `CLAUDE_HOOK_EVENT_NAME` is "the documented env var set by Claude Code". This is factually wrong and will mislead future readers. The comment must be corrected even apart from the code fix.

### Non-blocking recommendations (follow-ups, not required for this PR)

1. **Log rotation / cap**: `sync-lib.invocations.log` grows unbounded. Henry suggests trimming to last N lines or rotating at a size threshold. Reasonable long-term concern, but explicitly marked non-blocking.
2. **Test coverage**: A test for `record_invocation` with a stubbed stdin payload would guard against regression. Non-blocking.

---

## Proposed Code Changes

### Change 1: Capture stdin early as `HOOK_INPUT`

Add immediately after `INVOCATION_LOG=...` (before the `log()` function):

```bash
# Capture the hook payload JSON once. Guarded against an interactive TTY so
# `bash sync-lib.sh` (manual invocation) doesn't block on cat waiting for EOF.
HOOK_INPUT=""
if [ ! -t 0 ]; then
  HOOK_INPUT="$(cat 2>/dev/null || true)"
fi
```

**Why `! -t 0`**: stdin is not a TTY during hook execution (Claude Code pipes the JSON payload), but IS a TTY during a manual `bash sync-lib.sh` invocation. The guard prevents blocking on `cat` when run interactively. This is the exact same pattern Henry suggests. The two sibling hooks (skill-required, github-app) use unconditional `cat` — they work because those hooks are never expected to be run manually. `sync-lib.sh` could be.

### Change 2: Fix `record_invocation` to read `HOOK_INPUT` instead of the env var

In `record_invocation`, add a `hook_event` local variable, drop `${CLAUDE_HOOK_EVENT_NAME:-unknown}`, and parse from `HOOK_INPUT` with jq (opportunistically — graceful fallback when jq is absent):

```bash
record_invocation() {
  local outcome="$1"
  local plugin_version="unknown"
  local hook_event="unknown"
  if [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
    plugin_version="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' \
      "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null \
      | head -1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    [ -z "$plugin_version" ] && plugin_version="unknown"
  fi
  if [ -n "${HOOK_INPUT:-}" ] && command -v jq >/dev/null 2>&1; then
    hook_event="$(printf '%s' "$HOOK_INPUT" \
      | jq -r '.hook_event_name // "unknown"' 2>/dev/null || echo "unknown")"
    [ -z "$hook_event" ] && hook_event="unknown"
  fi
  mkdir -p "$(dirname "$INVOCATION_LOG")"
  printf '%s event=%s version=%s outcome=%s root=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$hook_event" \
    "$plugin_version" \
    "$outcome" \
    "$CLAUDE_PLUGIN_ROOT" \
    >>"$INVOCATION_LOG" 2>/dev/null || true
}
```

**Key design decisions:**
- `jq` used opportunistically (`command -v jq`) — version field still uses grep/sed so no hard jq dep
- `printf '%s' "$HOOK_INPUT" | jq` avoids subshell stdin conflict vs `echo "$HOOK_INPUT"` (safe for arbitrary JSON)
- Fallback chain: no jq → `hook_event=unknown`; jq fails → `hook_event=unknown`; `.hook_event_name` null → `"unknown"`

### Change 3: Fix the incorrect comment

Replace the comment on the `record_invocation` function header:

**Old:**
```bash
# Record this invocation. CLAUDE_HOOK_EVENT_NAME is the documented env var
# set by Claude Code when firing hooks (Setup / SessionStart / etc.).
```

**New:**
```bash
# Record this invocation. The hook event name is delivered in the stdin
# JSON payload as `hook_event_name`; there is no CLAUDE_HOOK_EVENT_NAME
# env var. Captured once at top-level (see HOOK_INPUT below) so the
# trap-driven record_invocation can read it without re-reading stdin.
# Plugin version is grep'd from plugin.json so we don't take a hard jq
# dep just for version; jq is only used opportunistically for event name.
```

---

## Items I Disagree With

None. Henry's blocking finding is correct and verified against:
- [Official hooks docs](https://code.claude.com/docs/en/hooks) — confirms env var list
- Two sibling hooks in this repo showing the correct `cat | jq` pattern
- The current code which uses `${CLAUDE_HOOK_EVENT_NAME:-unknown}` (will always be `unknown`)

Henry's suggested code is the right fix. The TTY guard addition is prudent for a script that may also be run manually.

---

## Non-blocking follow-ups (NOT implementing in this PR)

- Log rotation: will track as a separate issue if Nate wants it
- Test coverage: same — separate follow-up

---

## Steps After Plan Approval

1. Checkout `fix/sync-lib-diagnostic-log` branch
2. Apply the three changes above to `plugins/shared-lib/hooks/scripts/sync-lib.sh`
3. Commit with message: `fix(shared-lib): read hook_event_name from stdin JSON, not env`
4. Push to `origin/fix/sync-lib-diagnostic-log`
5. Respond in Henry's inline comment thread (comment 3252272757) explaining what changed and why
6. Remove then re-add `request-review` label (PR is draft — `synchronize` doesn't re-fire workflow)
7. Report final state

---

## References

- [PR #510](https://github.com/nsheaps/ai-mktpl/pull/510)
- [Henry's review body](https://github.com/nsheaps/ai-mktpl/pull/510#pullrequestreview-4303068484)
- [Henry's inline comment](https://github.com/nsheaps/ai-mktpl/pull/510#discussion_r3252272757)
- [Claude Code hooks docs](https://code.claude.com/docs/en/hooks)
- [skill-required hook (correct pattern)](https://github.com/nsheaps/ai-mktpl/blob/main/plugins/skill-required/hooks/scripts/check-skill-required.sh)
- [github-app hook (correct pattern)](https://github.com/nsheaps/ai-mktpl/blob/main/plugins/github-app/hooks/scripts/github-token-check.sh)
