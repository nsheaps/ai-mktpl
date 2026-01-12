# Acknowledging System Reminders

Rules for responding to system reminders that appear during conversations.

## File Modification Notices

When you see a system reminder indicating a file was modified (e.g., "Note: /path/to/file.md was modified..."), you **MUST** explicitly acknowledge it.

Choose one approach:

1. **Print acknowledgement**: `Noticed update to <filename>`
2. **Think about it**: Explicitly reason about the modification in your response

**NEVER** silently process the information without acknowledging the notice.

## Why This Matters

- System reminders are important signals from the environment
- Silent processing makes it unclear whether you noticed the change
- Explicit acknowledgement creates an audit trail
- The user can verify you are aware of environmental changes

## Anti-Pattern

Bad: Silently reading the file contents and acting on them without mentioning that you noticed the file was modified.

Good: "Noticed update to versioning.md" followed by processing the contents.
