---
name: chat
description: >
  Use this skill when the user asks about Google Chat operations like
  sending messages, managing spaces, or listing conversations via the
  Google Workspace CLI.
---

# Google Chat via Google Workspace CLI

Use `gws chat` to interact with Google Chat from the command line.

## Common Operations

### Spaces (Rooms/Channels)

```bash
# List spaces
gws chat spaces list

# Get space details
gws chat spaces get <space-name>

# Create a space
gws chat spaces create --display-name "Project Alpha" --type "ROOM"

# List members of a space
gws chat spaces members list <space-name>
```

### Messages

```bash
# List messages in a space
gws chat messages list <space-name>

# Send a message to a space
gws chat messages create <space-name> --text "Hello team!"

# Send a message with formatting
gws chat messages create <space-name> --text "*Bold* and _italic_ text"

# Reply to a thread
gws chat messages create <space-name> --text "Reply here" --thread <thread-name>

# Get a specific message
gws chat messages get <message-name>

# Update a message
gws chat messages update <message-name> --text "Updated message"

# Delete a message
gws chat messages delete <message-name>
```

### Reactions

```bash
# Add a reaction
gws chat messages reactions create <message-name> --emoji "thumbsup"

# List reactions
gws chat messages reactions list <message-name>
```

## Space Types

| Type             | Description              |
| ---------------- | ------------------------ |
| `ROOM`           | Named space with threads |
| `GROUP_CHAT`     | Group direct message     |
| `DIRECT_MESSAGE` | 1:1 direct message       |

## Tips

- Space names follow the format `spaces/<space-id>`
- Message names follow the format `spaces/<space-id>/messages/<message-id>`
- Google Chat API requires a Google Workspace account (not consumer Gmail)
- Use `--format json` for machine-readable output
