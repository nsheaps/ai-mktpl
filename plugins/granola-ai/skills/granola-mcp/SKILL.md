---
name: granola-mcp
description: >
  Use the Granola.ai MCP server to search meetings, retrieve transcripts, and analyze meeting patterns.
  Provides guidance on tool usage, limitations, and best practices for working with meeting data.
allowed-tools: mcp__granola-ai__search_meetings, mcp__granola-ai__get_meeting_details, mcp__granola-ai__get_meeting_transcript, mcp__granola-ai__get_meeting_documents, mcp__granola-ai__analyze_meeting_patterns
---

# Granola MCP Server Skill

Access Granola.ai meeting data through the MCP server. All data is read from Granola's local cache - no external API calls are made.

## Available Tools

### search_meetings

Search for meetings by title, content, or participants.

```
mcp__granola-ai__search_meetings
  query: string (required) - Search query for meetings
  limit: integer (optional) - Maximum results, default 10
```

**CRITICAL LIMITATION**: Results do **not** return in any specified order. You cannot specify ordering (by date, relevance, etc.). If you need chronological ordering, you must:

1. Fetch results with a higher limit
2. Sort them yourself after retrieval
3. Use `get_meeting_details` to get precise timestamps for sorting

### get_meeting_details

Get comprehensive metadata for a specific meeting.

```
mcp__granola-ai__get_meeting_details
  meeting_id: string (required) - Meeting ID to retrieve
```

Returns: Title, date/time (local timezone), duration, participants, and summary.

### get_meeting_transcript

Retrieve the full transcript with speaker identification.

```
mcp__granola-ai__get_meeting_transcript
  meeting_id: string (required) - Meeting ID to get transcript for
```

Returns: Complete conversation with speaker labels. Can handle 25,000+ character transcripts.

### get_meeting_documents

Get notes and summaries associated with a meeting.

```
mcp__granola-ai__get_meeting_documents
  meeting_id: string (required) - Meeting ID to get documents for
```

Returns: Meeting notes, summaries, and any attached documents.

### analyze_meeting_patterns

Identify patterns across multiple meetings.

```
mcp__granola-ai__analyze_meeting_patterns
  pattern_type: string (required) - "topics", "participants", or "frequency"
  date_range: object (optional)
    start_date: string - ISO date format
    end_date: string - ISO date format
```

Returns: Analysis of trends based on the selected pattern type.

## Usage Patterns

### Finding Recent Meetings

Since `search_meetings` doesn't guarantee order, use this pattern:

```
1. search_meetings(query="*", limit=50)  # Get many results
2. For each result, note the meeting_id
3. get_meeting_details for each to get timestamps
4. Sort by timestamp in your logic
5. Return the most recent N
```

### Searching for Specific Topics

```
1. search_meetings(query="quarterly review", limit=10)
2. Review results - they may span various time periods
3. Use get_meeting_details to understand context of each
```

### Getting Full Meeting Context

```
1. get_meeting_details(meeting_id) - metadata and summary
2. get_meeting_transcript(meeting_id) - full conversation
3. get_meeting_documents(meeting_id) - notes and attachments
```

### Analyzing Trends

```
# Who have I met with most?
analyze_meeting_patterns(pattern_type="participants")

# What topics recur?
analyze_meeting_patterns(pattern_type="topics", date_range={start_date: "2024-01-01"})

# How often do I have meetings?
analyze_meeting_patterns(pattern_type="frequency")
```

## Limitations

| Limitation         | Impact                                      | Workaround                        |
| ------------------ | ------------------------------------------- | --------------------------------- |
| No result ordering | `search_meetings` returns unordered results | Fetch more results, sort manually |
| Read-only          | Cannot create/modify meetings               | Use Granola.ai app directly       |
| Cache-dependent    | Only sees cached data                       | Ensure Granola app is synced      |
| macOS only         | Desktop app required                        | No workaround                     |

## Best Practices

1. **Always fetch more than you need** when searching - you'll need to filter/sort
2. **Cache meeting IDs** if you'll reference them multiple times in a session
3. **Use pattern analysis** for high-level insights before diving into specific meetings
4. **Check meeting details** before fetching full transcripts - transcripts can be large

## References

- **MCP Server Source**: https://github.com/proofgeist/granola-ai-mcp-server
- **Granola.ai Documentation**: https://granola.ai
