# Forum Thread Creation via Discord API

Create threads in Discord forum channels using the REST API. The Discord MCP `reply` tool cannot create new forum threads -- it can only reply to existing messages. Use the API directly for thread creation.

## When to Use

- Creating new forum threads (e.g., work tracking, mergeathon milestones, discussion topics)
- The MCP `reply` tool returns errors when targeting a forum channel directly

## API Endpoint

```
POST https://discord.com/api/v10/channels/{forum_channel_id}/threads
```

## Headers

```
Authorization: Bot ${DISCORD_BOT_TOKEN}
Content-Type: application/json
```

The bot token is available via the `$DISCORD_BOT_TOKEN` environment variable. Never hardcode it.

## Request Body

```json
{
  "name": "Thread title",
  "type": 11,
  "auto_archive_duration": 10080,
  "message": {
    "content": "Initial message content"
  }
}
```

| Field | Value | Notes |
|-------|-------|-------|
| `name` | string | Thread title (max 100 chars) |
| `type` | `11` | Public thread (required for forum channels) |
| `auto_archive_duration` | `10080` | 7 days in minutes (max value) |
| `message.content` | string | The first message in the thread (required for forum threads) |

## Full Example

```bash
curl -X POST "https://discord.com/api/v10/channels/${FORUM_CHANNEL_ID}/threads" \
  -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Thread Title Here",
    "type": 11,
    "auto_archive_duration": 10080,
    "message": {
      "content": "Initial message content here."
    }
  }'
```

The response includes the created thread object with `id` (the new thread's channel ID) which can then be used with the MCP `reply` tool for follow-up messages.

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| **403 Forbidden** | Bot lacks permissions | Grant **Manage Threads** and **Create Public Threads** permissions in the forum channel |
| **400 Bad Request** "Invalid channel type" | Target channel is not a forum | Forum channels have type `15`. Verify with `GET /channels/{id}` |
| **400 Bad Request** "Missing message content" | No `message` field in body | Forum threads require an initial message |

## MCP Reply Tool Limitation

The Discord MCP `reply` tool works by sending a message to a channel. Forum channels (type 15) do not accept direct messages -- they only accept thread creation. This means:

- **Creating a thread**: Must use the REST API (this skill)
- **Replying in a thread**: Use the MCP `reply` tool with the thread's channel ID (returned in the creation response as `id`)

## References

- [Discord API: Start Thread in Forum](https://discord.com/developers/docs/resources/channel#start-thread-in-forum-or-media-channel)
- [Discord API: Channel Types](https://discord.com/developers/docs/resources/channel#channel-object-channel-types)
