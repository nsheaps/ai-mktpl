# Plugin: shared-lib

**Purpose**: TODO: add description

## Hooks

- `SessionStart` (`bash`) — Copy bundled lib/ files from CLAUDE_PLUGIN_ROOT into CLAUDE_PLUGIN_DATA. Registered on BOTH Setup{init} (fires during `claude --init-only` pre-pass for fast first-install) AND SessionStart (fires every session, picks up plugin updates and self-heals manual deletion). The manifest-diff check in sync-lib.sh makes repeat invocations a fast no-op when content is unchanged.
- `Setup` (`bash`) — Copy bundled lib/ files from CLAUDE_PLUGIN_ROOT into CLAUDE_PLUGIN_DATA. Registered on BOTH Setup{init} (fires during `claude --init-only` pre-pass for fast first-install) AND SessionStart (fires every session, picks up plugin updates and self-heals manual deletion). The manifest-diff check in sync-lib.sh makes repeat invocations a fast no-op when content is unchanged.

