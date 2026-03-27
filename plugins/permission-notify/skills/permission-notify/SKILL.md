# permission-notify

Skill for the `permission-notify` plugin — Telegram notifications on Claude Code permission requests.

## What This Plugin Does

The `permission-notify` plugin fires on every `PermissionRequest` hook event and sends a Telegram
message summarizing the pending operation. It is purely informational — it never blocks or overrides
the permission decision.

## Notification Format

```
🔒 Permission Request: {tool_name}
📁 {file_path or command}
📝 {diff preview or content summary}
```

Sent via the Telegram Bot API with HTML parse mode.

## Configuration

Set the following environment variables before starting the Claude Code session:

| Variable             | Required | Default     | Description                          |
|----------------------|----------|-------------|--------------------------------------|
| `TELEGRAM_BOT_TOKEN` | Yes      | —           | Telegram Bot API token               |
| `TELEGRAM_CHAT_ID`   | No       | `1650664303`| Chat ID to receive notifications     |

### Recommended: inject via op-exec

```yaml
# .claude/plugins.settings.yaml
permission-notify:
  enabled: true
```

```bash
# In your session startup, inject the token via op-exec or env:
export TELEGRAM_BOT_TOKEN="$(op read 'op://vault/telegram-bot/token')"
```

Or use the `1pass` / `op-exec` plugin to inject secrets automatically.

## Supported Tools

| Tool    | Detail shown        | Summary shown                          |
|---------|---------------------|----------------------------------------|
| `Edit`  | File path           | First 400 chars of old/new diff        |
| `Write` | File path           | First 200 chars of content             |
| `Bash`  | —                   | Full command (up to 200 chars)         |
| `Read`  | File path           | —                                      |
| Others  | Key-value of inputs | First 200 chars of stringified inputs  |

## Notes

- The notification is sent asynchronously (background `curl`) — it never delays the permission decision
- The hook outputs no `permissionDecision` field, so Claude Code falls through to its normal flow
- If `TELEGRAM_BOT_TOKEN` is unset, the hook exits silently with no effect

## References

- [Telegram Bot API: sendMessage](https://core.telegram.org/bots/api#sendmessage)
- [Claude Code hooks documentation](https://docs.claude.ai/en/docs/claude-code/hooks)
