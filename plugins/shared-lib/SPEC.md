# Plugin: shared-lib

**Purpose**: Shared bash libraries used by other ai-mktpl plugins (logging, hook output, config reading, settings writing, tool install). Other plugins declare this as a dependency and source the libs from this plugin's persistent data directory at runtime.

## Hooks

- `Setup` (`bash`) — Copy bundled lib/ files from CLAUDE_PLUGIN_ROOT into CLAUDE_PLUGIN_DATA. Registered on BOTH Setup{init} (fires during `claude --init-only` pre-pass for fast first-install) AND SessionStart (fires every session, picks up plugin updates and self-heals manual deletion). The manifest-diff check in sync-lib.sh makes repeat invocations a fast no-op when content is unchanged.
- `SessionStart` (`bash`) — Copy bundled lib/ files from CLAUDE_PLUGIN_ROOT into CLAUDE_PLUGIN_DATA. Registered on BOTH Setup{init} (fires during `claude --init-only` pre-pass for fast first-install) AND SessionStart (fires every session, picks up plugin updates and self-heals manual deletion). The manifest-diff check in sync-lib.sh makes repeat invocations a fast no-op when content is unchanged.
