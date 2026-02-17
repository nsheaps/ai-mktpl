# Transcript Monitor Plugin

**Status:** Draft
**Priority:** High (impacts session stability)

## Problem Statement

Claude Code session transcripts (`.jsonl` files in `~/.claude/projects/`) can contain extremely large lines (>10kB, sometimes >1MB) from:

- Tool results returning large file contents or command output
- Images encoded as base64
- Large API responses
- Accidentally reading binary or generated files

These oversized lines cause:

- **Session crashes** on startup when the context can't be loaded ([claude-code#20470](https://github.com/anthropics/claude-code/issues/20470))
- **Failed compaction** when context approaches limits
- **Slow session resume** from parsing massive JSON lines
- **Unrecoverable sessions** requiring manual intervention to fix

Currently the only fix is manual: identify the large line, back it up, and replace it with a stub - a tedious and error-prone process.

## Solution

A Claude Code plugin that monitors transcript files and automatically extracts oversized lines to a separate location, replacing them with lightweight stubs that reference the extracted content.

## Technical Design

### Hook: PostToolUse / Stop

After each tool use (or at session stop), check the current session's transcript file for lines exceeding a configurable threshold.

```bash
# Pseudocode for the hook
SESSION_FILE="~/.claude/projects/$PROJECT_ID/$SESSION_ID.jsonl"
THRESHOLD_BYTES=10240  # 10kB default

# Check last N lines (since we only need to catch new additions)
tail -n 5 "$SESSION_FILE" | while IFS= read -r line; do
  line_size=$(echo "$line" | wc -c)
  if [ "$line_size" -gt "$THRESHOLD_BYTES" ]; then
    extract_and_replace "$SESSION_FILE" "$line"
  fi
done
```

### Extraction Process

1. **Identify** the oversized line number and its JSON metadata (uuid, parentUuid, type)
2. **Backup** the original line to `~/.claude/backups/YYYY-MM-DD/projects/$projectId/$sessionId/$lineNumber.jsonl`
3. **Replace** the line in-place with a stub JSON object preserving the same uuid/parentUuid/type but with truncated content:
   ```json
   {
     "uuid": "...",
     "parentUuid": "...",
     "type": "...",
     "message": {
       "role": "user",
       "content": "ERROR: CONTENTS REMOVED FROM HISTORY. LINE TOO BIG (SIZE bytes). FIND ORIGINAL AT ~/.claude/backups/YYYY-MM-DD/projects/$projectId/$sessionId/$lineNumber.jsonl"
     }
   }
   ```
4. **Log** the extraction to the session debug file

### Configuration

Plugin settings via `.claude/transcript-monitor.local.md` frontmatter:

```yaml
---
threshold_bytes: 10240 # Lines larger than this get extracted (default: 10kB)
check_frequency: stop # When to check: "every_tool" or "stop" (default: stop)
backup_dir: ~/.claude/backups # Where to store extracted lines
dry_run: false # Log but don't modify (for testing)
---
```

### Safety Considerations

- **Never modify while session is active** if using `stop` frequency - only safe to modify transcript when session is ending
- **Always backup before modifying** - originals must be recoverable
- **Preserve JSON structure** - replacement must be valid JSONL with correct uuid/parentUuid chain
- **Atomic replacement** - use temp file + rename pattern to avoid corruption
- **Don't process the current line being written** - only check lines that are already committed to the file

### Edge Cases

- Multiple large lines in the same session
- Lines that are large due to legitimate content (should still extract with a more descriptive stub)
- Sessions that are already broken/corrupt
- Race conditions with Claude Code writing to the same file

## Plugin Structure

```
plugins/transcript-monitor/
  .claude-plugin/
    plugin.json
  hooks/
    hooks.json          # Stop hook (and optionally PostToolUse)
    check-transcript.sh # Main extraction logic
  skills/
    transcript-monitor/
      SKILL.md          # Usage docs
  bin/
    extract-line.sh     # Standalone script for manual extraction
```

## MVP Scope

1. **Stop hook** that checks transcript on session end
2. **Single threshold** (10kB default)
3. **Backup + replace** with stub message
4. **Debug logging** to session debug file
5. **Manual CLI** (`bin/extract-line.sh`) for fixing existing broken sessions

## Future Enhancements

- Real-time monitoring via PostToolUse hook
- Configurable per-project thresholds
- Dashboard showing transcript sizes across sessions
- Auto-cleanup of old backups
- Integration with the statusline plugin to show transcript health
- PreToolUse hook that warns before reading files likely to produce large output
