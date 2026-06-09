<!-- UPSTREAM: discord -->
---
name: dumping-channel-content
description: Export a Discord channel or thread to JSONL for audit, analysis, or transcript review. Use when you need offline access to a conversation, want to grep history, or need to verify message completeness.
user-invocable: false
allowed-tools:
  - Bash(python3 *)
  - Read
  - Write
---

# discord:dumping-channel-content

Exports Discord channel or thread messages to JSON Lines (`.jsonl`) files using
the Discord REST API v10. Stdlib-only — no external dependencies beyond Python 3.

## When to use

- **Auditing**: capture a conversation before deletion or archival
- **Analysis**: grep, filter, or process message history offline
- **Transcript exports**: produce a permanent record of a forum thread or DM thread
- **Completeness verification**: confirm all messages were received (use `--verify`)

## Script location

```
plugins/discord/scripts/discord-dump.py
```

## Authentication

The script reads the bot token from an environment variable (default:
`DISCORD_BOT_TOKEN`). Override with `--token-env OTHER_VAR_NAME`. The bot must
have `Read Message History` permission in the target channel.

```bash
export DISCORD_BOT_TOKEN=<bot-token>
```

## Basic invocation

```bash
# Dump a single channel
python3 plugins/discord/scripts/discord-dump.py \
  -g GUILD_ID -c CHANNEL_ID -o out.jsonl

# Dump a channel plus all its threads (one file per thread, output is a dir)
python3 plugins/discord/scripts/discord-dump.py \
  -g GUILD_ID -c CHANNEL_ID --with-threads -o out-dir/

# Dump every channel in a guild (skips voice/category channels)
python3 plugins/discord/scripts/discord-dump.py \
  -g GUILD_ID --all --with-threads -o dump/

# Dump a specific forum thread
python3 plugins/discord/scripts/discord-dump.py \
  -g GUILD_ID -c FORUM_CHANNEL_ID -t THREAD_ID -o thread.jsonl

# Date-range and user filter
python3 plugins/discord/scripts/discord-dump.py \
  -g GUILD_ID -c CHANNEL_ID \
  --start 2026-05-01 --end 2026-06-01 \
  --user USER_SNOWFLAKE_ID -o filtered.jsonl
```

## Arguments

| Flag | Short | Description |
|---|---|---|
| `--guild` | `-g` | Guild (server) ID. Falls back to `$DISCORD_GUILD_ID`. |
| `--channel` | `-c` | Channel ID to dump. Falls back to `$DISCORD_CHANNEL_ID`. |
| `--thread` | `-t` | Specific thread ID within a forum channel. |
| `--all` | | Dump every text/forum channel in the guild. |
| `--with-threads` | | Also dump all threads attached to the channel. |
| `--forum` | | Treat `--channel` as a forum and dump every thread. |
| `--start` | | ISO date lower bound (`YYYY-MM-DD`, inclusive). |
| `--end` | | ISO date upper bound (`YYYY-MM-DD`, inclusive). |
| `--user` | | Filter to messages from this user snowflake (repeatable). |
| `--exclude-user` | | Exclude messages from this user snowflake (repeatable). |
| `--output` | `-o` | **Required.** Output `.jsonl` file or directory path. |
| `--verify` | | After writing, re-fetch message counts and assert no gaps. |
| `--token-env` | | Env var name holding the bot token (default `DISCORD_BOT_TOKEN`). |
| `--max-retries` | | Max HTTP retries on rate-limit/5xx (default 8). |
| `--verbose` | `-v` | Print per-request progress. |

## Output format

Each line of the output `.jsonl` file is one Discord message object as returned
by the REST API, with no transformation. Fields include `id`, `content`,
`author`, `timestamp`, `attachments`, `embeds`, `reactions`, etc.

When `--with-threads` or `--all` is used and the output path is a directory,
the script writes one `.jsonl` file per channel/thread named by a safe slug of
the channel name.

## The `--verify` flag

After writing, the script re-fetches message snowflake ranges and asserts the
written file contains no gaps. Use this when you need high-confidence exports
(e.g., legal/compliance audits or completeness checks after a long dump). Adds
a second round-trip per channel.

## Starter message handling

The script skips the first pinned "starter message" on forum threads (the post
body that Discord synthesises as a message) to avoid double-counting content
already captured in the thread metadata.
