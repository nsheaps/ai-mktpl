---
name: gmail
description: >
  Use this skill when the user asks about reading, sending, searching, or
  managing emails via the Google Workspace CLI. Trigger on Gmail-related tasks
  like composing emails, searching inbox, managing labels, archiving, or
  working with drafts.
---

# Gmail via Google Workspace CLI

Use `gws gmail` to interact with Gmail from the command line.

## Common Operations

### List and Search Messages

```bash
# List recent emails
gws gmail list

# List unread emails
gws gmail list --unread --limit 20

# Search emails (uses Gmail search syntax)
gws gmail search "from:boss@example.com"
gws gmail search "subject:meeting is:unread"
gws gmail search "has:attachment newer_than:7d"
gws gmail search "label:important in:inbox"
```

### Read Messages

```bash
# Read a specific message
gws gmail read <message-id>

# Read with full headers
gws gmail read <message-id> --full

# Read as JSON for parsing
gws gmail read <message-id> --format json
```

### Send and Reply

```bash
# Send a new email
gws gmail send --to "user@example.com" --subject "Hello" --body "Message body"

# Send with CC/BCC
gws gmail send --to "user@example.com" --cc "cc@example.com" --subject "Hello" --body "Body"

# Reply to a message
gws gmail reply <message-id> --body "Thanks for the update"

# Forward a message
gws gmail forward <message-id> --to "other@example.com"
```

### Drafts

```bash
# Create a draft
gws gmail draft create --to "user@example.com" --subject "Draft" --body "Content"

# List drafts
gws gmail draft list

# Send a draft
gws gmail draft send <draft-id>
```

### Manage Messages

```bash
# Archive a message
gws gmail archive <message-id>

# Mark as read/unread
gws gmail mark-read <message-id>
gws gmail mark-unread <message-id>

# Add/remove labels
gws gmail label add <message-id> "MyLabel"
gws gmail label remove <message-id> "MyLabel"

# Move to trash
gws gmail trash <message-id>
```

### Labels

```bash
# List all labels
gws gmail labels list

# Create a label
gws gmail labels create "MyNewLabel"
```

## Gmail Search Syntax

Gmail supports powerful search operators:

| Operator | Example | Description |
|----------|---------|-------------|
| `from:` | `from:user@example.com` | Sender |
| `to:` | `to:user@example.com` | Recipient |
| `subject:` | `subject:meeting` | Subject line |
| `is:` | `is:unread`, `is:starred` | Message state |
| `has:` | `has:attachment` | Has attachments |
| `in:` | `in:inbox`, `in:sent` | Mailbox location |
| `label:` | `label:important` | Has label |
| `newer_than:` | `newer_than:7d` | Date range |
| `older_than:` | `older_than:30d` | Date range |
| `filename:` | `filename:pdf` | Attachment type |

## JSON Output

All commands support `--format json` for machine-readable output:

```bash
gws gmail list --format json | jq '.[].subject'
```
