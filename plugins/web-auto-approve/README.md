# web-auto-approve

Auto-approve `Edit`, `Write`, and `Bash` permission requests in Claude Code web sessions.

## Why

Since Claude Code v2.1.78, writes to protected directories (`.git`, `.claude`, `.vscode`, `.idea`) prompt for confirmation even with `bypassPermissions` enabled. In web sessions there is no interactive user to approve these prompts, so they block the agent.

This plugin uses a `PermissionRequest` hook to automatically approve these tool calls when `CLAUDE_CODE_REMOTE` is set (i.e., running in a web session). Local CLI sessions are unaffected and still receive normal permission prompts.

## How it works

The `PermissionRequest` hook fires after permission rules evaluate but before the user dialog appears. When running in a web session, it emits an `allow` decision for `Edit`, `Write`, and `Bash` tool calls.

## TODO

- [ ] Test whether the plugin's PermissionRequest hooks are picked up fast enough at session start to replace the inline hooks in `.claude/settings.json`. If so, remove the duplicate inline `PermissionRequest` hooks from settings.json. The concern is that plugin hooks may not be registered before the first permission prompt fires. See #261.

## Related

- [#261](https://github.com/nsheaps/ai-mktpl/issues/261) - Repeated permissions issues since claude-code CLI update
- [anthropics/claude-code#36044](https://github.com/anthropics/claude-code/issues/36044)
