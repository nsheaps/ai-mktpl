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

A Claude Code plugin that monitors transcript files and automatically extracts oversized lines to a co-located directory, replacing them with lightweight stubs that reference the extracted content.

## Technical Design

### Hook Events

The plugin runs on **four** hook events:

| Event            | Purpose                                                                       |
| ---------------- | ----------------------------------------------------------------------------- |
| **SessionStart** | Scan for oversized lines from previous sessions that may not have been caught |
| **PostToolUse**  | Catch large tool results immediately after they're written                    |
| **SubagentStop** | Catch large sub-agent responses when agents complete                          |
| **Stop**         | Final sweep before session ends                                               |

### Extraction Path

Extracted content lives alongside the session transcript, not in a separate backup tree:

```
~/.claude/projects/<project-path>/<session-uuid>/extracted-responses/<mini-sha>-<short-description>.txt
```

Where:

- `<project-path>` - the project identifier directory (e.g., `-Users-nathan-heaps-src-stainless-api-stainless`)
- `<session-uuid>` - the session ID (e.g., `6ecff1b0-eb80-4c6a-8312-8b9d3e86e85d`)
- `<mini-sha>` - first 7 characters of the line's `uuid` field
- `<short-description>` - derived from the line content: tool name, agent description, or message summary, kebab-cased and truncated to ~50 chars

**Example:**

A large tool result from an agent fixing lint errors on PR 15906 would extract to:

```
~/.claude/projects/-Users-nathan-heaps-src-stainless-api-stainless/6ecff1b0-eb80-4c6a-8312-8b9d3e86e85d/extracted-responses/a60a882-agent-fix-lint-errors-pr-15906.txt
```

### Deriving the Short Description

The description is generated from the JSON line content by checking fields in priority order:

1. **Agent task description** - if the line is a sub-agent result, use the task `description` field
2. **Tool name + input summary** - if it's a tool result, use `toolName` and summarize the input (e.g., `bash-git-diff-main`, `read-src-components-app-tsx`)
3. **Message role + truncated content** - fallback: `user-message` or `assistant-response`

Rules for formatting:

- Lowercase, kebab-case
- Strip special characters
- Truncate to 50 chars max (at word boundary)
- Ensure filesystem-safe characters only

### Hook Logic

```bash
#!/usr/bin/env bash
set -e

SESSION_FILE="$HOME/.claude/projects/$PROJECT_ID/$SESSION_ID.jsonl"
EXTRACT_DIR="$HOME/.claude/projects/$PROJECT_ID/$SESSION_ID/extracted-responses"
THRESHOLD_BYTES=10240  # 10kB default

# Check last N lines (since we only need to catch new additions)
# On SessionStart, scan the full file; on other events, check recent lines
if [ "$HOOK_EVENT" = "SessionStart" ]; then
  lines_to_check=$(wc -l < "$SESSION_FILE")
else
  lines_to_check=5
fi

tail -n "$lines_to_check" "$SESSION_FILE" | while IFS= read -r line; do
  line_size=$(printf '%s' "$line" | wc -c)
  if [ "$line_size" -gt "$THRESHOLD_BYTES" ]; then
    uuid=$(printf '%s' "$line" | jq -r '.uuid // empty')
    mini_sha="${uuid:0:7}"
    description=$(derive_description "$line")  # see "Deriving the Short Description"

    # Extract to file
    mkdir -p "$EXTRACT_DIR"
    extract_path="$EXTRACT_DIR/${mini_sha}-${description}.txt"
    printf '%s' "$line" > "$extract_path"

    # Build replacement stub
    parent_uuid=$(printf '%s' "$line" | jq -r '.parentUuid // empty')
    line_type=$(printf '%s' "$line" | jq -r '.type // empty')
    replacement=$(jq -cn \
      --arg uuid "$uuid" \
      --arg parentUuid "$parent_uuid" \
      --arg type "$line_type" \
      --arg size "$line_size" \
      --arg path "$extract_path" \
      '{type: $type, uuid: $uuid, parentUuid: $parentUuid,
        message: {role: "user", content: ("ERROR: CONTENTS EXTRACTED FROM HISTORY. LINE TOO BIG (" + $size + " bytes). FIND ORIGINAL AT " + $path)}}')

    # Replace in-place using line number
    line_number=$(grep -n "\"uuid\":\"$uuid\"" "$SESSION_FILE" | head -1 | cut -d: -f1)
    replace_line "$SESSION_FILE" "$line_number" "$replacement"
  fi
done
```

### Replacement Stub

The in-place replacement preserves the JSON structure with the same uuid/parentUuid/type:

```json
{
  "type": "user",
  "uuid": "a60a882...",
  "parentUuid": "0834542...",
  "message": {
    "role": "user",
    "content": "ERROR: CONTENTS EXTRACTED FROM HISTORY. LINE TOO BIG (2119037 bytes). FIND ORIGINAL AT ~/.claude/projects/-Users-nathan-heaps-src-stainless-api-stainless/6ecff1b0-eb80-4c6a-8312-8b9d3e86e85d/extracted-responses/a60a882-agent-fix-lint-errors-pr-15906.txt"
  }
}
```

### Configuration

Plugin settings via `.claude/transcript-monitor.local.md` frontmatter:

```yaml
---
threshold_bytes: 10240 # Lines larger than this get extracted (default: 10kB)
dry_run: false # Log but don't modify (for testing)
---
```

### Safety Considerations

- **Atomic replacement** - use temp file + rename pattern to avoid corruption
- **Don't process the current line being written** - on PostToolUse, only check lines written before the current tool's result
- **Preserve JSON structure** - replacement must be valid JSONL with correct uuid/parentUuid chain
- **Idempotent** - if a line has already been extracted (stub references an extraction path), skip it
- **SessionStart is read-heavy** - full file scan should be fast since it's just checking line sizes, not parsing JSON for every line

### Edge Cases

- Multiple large lines in the same session
- Lines that are large due to legitimate content (still extract, the stub points to the original)
- Sessions that are already broken/corrupt
- Race conditions with Claude Code writing to the same file (mitigated by atomic temp-file replacement)
- Duplicate uuid short prefixes (unlikely with 7 chars, but append line number if collision)

## Plugin Structure

```
plugins/transcript-monitor/
  .claude-plugin/
    plugin.json
  hooks/
    hooks.json              # SessionStart, PostToolUse, SubagentStop, Stop
    check-transcript.sh     # Main extraction logic
  skills/
    transcript-monitor/
      SKILL.md              # Usage docs
  bin/
    extract-line.sh         # Standalone script for manual extraction of specific lines
```

## MVP Scope

1. **All four hooks** (SessionStart, PostToolUse, SubagentStop, Stop)
2. **Single threshold** (10kB default)
3. **Extract + replace** with stub pointing to co-located extraction directory
4. **Description derivation** from tool name / agent description
5. **Debug logging** to session debug file
6. **Manual CLI** (`bin/extract-line.sh`) for fixing existing broken sessions

## Future Enhancements

- Configurable per-project thresholds
- Dashboard showing transcript sizes across sessions
- Auto-cleanup of old extractions
- Integration with the statusline plugin to show transcript health
- PreToolUse hook that warns before reading files likely to produce large output
- Compression of extracted files (gzip)

## References

- [Claude Code Plugins Documentation](https://code.claude.com/docs/en/plugins)
- [claude-code#20470](https://github.com/anthropics/claude-code/issues/20470) - Context size crash issue
- Session transcripts: `~/.claude/projects/<project-path>/<session-uuid>.jsonl`
- Debug logs: `~/.claude/debug/<session-uuid>.txt`
