---
name: calendar
description: >
  Use this skill when the user asks about managing Google Calendar events,
  checking schedules, creating meetings, finding free time, or any
  calendar-related task via the Google Workspace CLI.
---

# Google Calendar via Google Workspace CLI

Use `gws calendar` to manage calendars and events from the command line.

## Common Operations

### List Calendars

```bash
# List all calendars
gws calendar list

# List with details
gws calendar list --format json
```

### View Events

```bash
# View upcoming events (default: today)
gws calendar events

# View events for the next N days
gws calendar events --days 7

# View events with limit
gws calendar events --days 14 --limit 20

# View events for a specific calendar
gws calendar events --calendar "Work"

# View a specific event
gws calendar event <event-id>
```

### Search Events

```bash
# Search events by text
gws calendar search "team meeting"

# Search within a date range
gws calendar search "standup" --after "2026-03-01" --before "2026-03-31"
```

### Create Events

```bash
# Create a simple event
gws calendar create "Team Meeting" \
  --start "2026-03-15 10:00" \
  --end "2026-03-15 11:00"

# Create with attendees
gws calendar create "Project Review" \
  --start "2026-03-15 14:00" \
  --end "2026-03-15 15:00" \
  --attendees "alice@example.com,bob@example.com"

# Create with location and description
gws calendar create "Offsite" \
  --start "2026-03-20 09:00" \
  --end "2026-03-20 17:00" \
  --location "Conference Room A" \
  --description "Quarterly planning session"

# Create an all-day event
gws calendar create "Company Holiday" \
  --date "2026-03-25" \
  --all-day

# Create on a specific calendar
gws calendar create "Personal Errand" \
  --start "2026-03-15 12:00" \
  --end "2026-03-15 13:00" \
  --calendar "Personal"
```

### Update Events

```bash
# Update event time
gws calendar update <event-id> \
  --start "2026-03-15 11:00" \
  --end "2026-03-15 12:00"

# Add attendees
gws calendar update <event-id> \
  --add-attendees "charlie@example.com"
```

### Delete Events

```bash
# Delete an event
gws calendar delete <event-id>
```

### Respond to Events

```bash
# Accept an event
gws calendar respond <event-id> --accept

# Decline an event
gws calendar respond <event-id> --decline

# Tentatively accept
gws calendar respond <event-id> --tentative
```

### Find Free Time

```bash
# Find free time slots
gws calendar free --days 5

# Find free time for multiple people
gws calendar free \
  --attendees "alice@example.com,bob@example.com" \
  --duration 60 \
  --days 5
```

## Date/Time Formats

The CLI accepts flexible date/time formats:

- `"2026-03-15 10:00"` - Specific date and time
- `"2026-03-15"` - Date only (for all-day events)
- `"tomorrow 10:00"` - Relative dates
- `"next monday 14:00"` - Named days

## JSON Output

```bash
# Get events as JSON for processing
gws calendar events --format json | jq '.[].summary'
```
