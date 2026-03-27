# permission-notify

Telegram notifications for Claude Code permission requests.

When Claude Code requests permission to use a tool (Edit, Write, Bash, etc.), this plugin fires a
Telegram notification with the tool name, target file or command, and a preview of what's changing.
The notification is purely informational — it never blocks or overrides the permission decision.

## Features

- **PermissionRequest hook**: Fires on every tool permission request
- **Async delivery**: Notification sent in background — zero latency impact
- **Rich previews**: Shows file paths, diff excerpts (Edit), command text (Bash), or content previews (Write)
- **HTML formatting**: Clean Telegram messages with bold headers and code blocks
- **Zero-config fallback**: If `TELEGRAM_BOT_TOKEN` is unset, hook exits silently

## Notification Format

```
🔒 Permission Request: Edit
📁 /repo/src/main.ts
📝 - const old = "before";
   + const new = "after";
```

## Setup

### 1. Get a Telegram Bot Token

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Create a bot with `/newbot`
3. Copy the token

### 2. Configure the Token

The plugin reads `TELEGRAM_BOT_TOKEN` from the environment. The recommended approach is to inject it
via the `1pass` plugin using `op-exec`:

```yaml
# .claude/plugins.settings.yaml
permission-notify:
  enabled: true
```

```bash
export TELEGRAM_BOT_TOKEN="$(op read 'op://vault/telegram-bot/token')"
```

Or source it from a file:

```bash
source ~/.config/agent/telegram-env
```

### 3. (Optional) Override the Chat ID

The default chat ID is `1650664303` (the handler's personal chat). Override with:

```bash
export TELEGRAM_CHAT_ID="your_chat_id"
```

To find your chat ID, message [@userinfobot](https://t.me/userinfobot).

## Configuration Reference

| Variable             | Required | Default      | Description                      |
| -------------------- | -------- | ------------ | -------------------------------- |
| `TELEGRAM_BOT_TOKEN` | Yes      | —            | Telegram Bot API token           |
| `TELEGRAM_CHAT_ID`   | No       | `1650664303` | Target chat ID for notifications |

## Plugin Structure

```
plugins/permission-notify/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── permission-notify.sh
├── skills/
│   └── permission-notify/
│       └── SKILL.md
└── README.md
```

## Security

- The hook never prints or logs the bot token
- Notifications are sent via HTTPS to the Telegram Bot API
- No permission decision is set — the hook is read-only with respect to Claude's permission flow

## Related

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Claude Code hooks](https://docs.claude.ai/en/docs/claude-code/hooks)
