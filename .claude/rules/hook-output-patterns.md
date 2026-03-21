# Hook Output Patterns

## PreToolUse: No Output = Defer to Default Authorization

When a PreToolUse hook has **no opinion** about a tool call (e.g., it only cares about `git commit` but the command is `git status`), it MUST output **nothing** to stdout and exit 0.

**Do NOT** output `{"hookSpecificOutput":{"permissionDecision":"allow"}}` for pass-through cases. An explicit `allow` bypasses the normal permission system entirely. No output defers to the default authorization process.

### When to Output JSON

| Scenario | Output | Effect |
|----------|--------|--------|
| Hook has no opinion | Nothing (exit 0) | Defer to permission system |
| Hook explicitly allows | `permissionDecision: "allow"` | Skip permission prompt |
| Hook explicitly denies | `permissionDecision: "deny"` | Block the tool call |
| Hook wants user confirmation | `permissionDecision: "ask"` | Prompt user |

### Correct Pattern

```bash
# Only care about git commit commands
if ! echo "$command" | grep -qE 'git\s+commit'; then
  exit 0  # No output — defer to default auth
fi

# Hook has an opinion about this command — output a decision
echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
exit 0
```

### Wrong Pattern

```bash
# DON'T do this — bypasses permission system for commands you don't care about
if ! echo "$command" | grep -qE 'git\s+commit'; then
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi
```

## PostToolUse: Advisory Only

PostToolUse hooks are advisory. They cannot block or modify tool calls. Output is informational (shown to Claude via `additionalContext`). No `permissionDecision` is needed.
