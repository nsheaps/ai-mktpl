#!/usr/bin/env python3
"""Dump Discord channel/thread messages to JSON Lines.

Uses the Discord REST API v10. Bot token from env (default DISCORD_BOT_TOKEN).
Stdlib only — no external deps.

Examples:
  # Dump a single channel
  DISCORD_BOT_TOKEN=... discord-dump.py -g 123 -c 456 -o out.jsonl

  # Dump a channel plus all its threads (one file per channel/thread)
  discord-dump.py -g 123 -c 456 --with-threads -o out-dir/

  # Dump every channel in a guild (skips voice/category)
  discord-dump.py -g 123 --all --with-threads -o dump/

  # Dump a specific forum thread
  discord-dump.py -g 123 -c 456 -t 789 -o thread.jsonl

  # Filter by date and user
  discord-dump.py -g 123 -c 456 --start 2026-05-01 --end 2026-06-01 \
                  --user 303922555947843585 -o filtered.jsonl
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API_BASE = "https://discord.com/api/v10"
USER_AGENT = "nsheaps-discord-dump/0.1 (+https://github.com/nsheaps/agents)"
DISCORD_EPOCH = 1420070400000  # ms

# Channel type constants we care about (Discord docs).
CT_GUILD_TEXT = 0
CT_GUILD_VOICE = 2
CT_GROUP_DM = 3
CT_GUILD_CATEGORY = 4
CT_GUILD_ANNOUNCEMENT = 5
CT_ANNOUNCEMENT_THREAD = 10
CT_PUBLIC_THREAD = 11
CT_PRIVATE_THREAD = 12
CT_GUILD_STAGE_VOICE = 13
CT_GUILD_FORUM = 15
CT_GUILD_MEDIA = 16

TEXTUAL_PARENTS = {CT_GUILD_TEXT, CT_GUILD_ANNOUNCEMENT}
FORUM_LIKE = {CT_GUILD_FORUM, CT_GUILD_MEDIA}
THREAD_TYPES = {CT_ANNOUNCEMENT_THREAD, CT_PUBLIC_THREAD, CT_PRIVATE_THREAD}


def log(msg: str, *, verbose: bool = True) -> None:
    if verbose:
        print(f"[discord-dump] {msg}", file=sys.stderr, flush=True)


def parse_iso_date(s: str) -> datetime:
    """Accept YYYY-MM-DD or full ISO8601. Always treated as UTC if naive."""
    try:
        if len(s) == 10:
            dt = datetime.strptime(s, "%Y-%m-%d")
        else:
            dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"invalid date {s!r}: {e}") from e
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def snowflake_for(dt: datetime) -> int:
    """Discord snowflake whose timestamp = dt. Used as a 'before' bound."""
    ms = int(dt.timestamp() * 1000) - DISCORD_EPOCH
    if ms < 0:
        ms = 0
    return ms << 22


def snowflake_timestamp(snowflake: int | str) -> datetime:
    s = int(snowflake)
    ms = (s >> 22) + DISCORD_EPOCH
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


class DiscordClient:
    def __init__(self, token: str, *, verbose: bool = False, max_retries: int = 8):
        self.token = token
        self.verbose = verbose
        self.max_retries = max_retries

    def _request(self, path: str, params: dict | None = None) -> tuple[int, dict, bytes]:
        url = f"{API_BASE}{path}"
        if params:
            url = f"{url}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bot {self.token}",
                "User-Agent": USER_AGENT,
                "Accept": "application/json",
            },
            method="GET",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, dict(resp.headers), resp.read()
        except urllib.error.HTTPError as e:
            return e.code, dict(e.headers or {}), e.read() or b""

    def get(self, path: str, params: dict | None = None):
        """GET with rate-limit + retry handling. Returns parsed JSON."""
        attempt = 0
        while True:
            try:
                status, headers, body = self._request(path, params)
            except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
                attempt += 1
                if attempt > self.max_retries:
                    raise
                delay = min(2 ** attempt, 60) + random.uniform(0, 1)
                log(f"network error {e!r}; retry {attempt}/{self.max_retries} in {delay:.1f}s",
                    verbose=self.verbose)
                time.sleep(delay)
                continue

            if status == 429:
                try:
                    payload = json.loads(body or b"{}")
                    retry = float(payload.get("retry_after", 1.0))
                except Exception:
                    retry = float(headers.get("Retry-After", "1"))
                log(f"429 rate-limited; sleeping {retry:.2f}s", verbose=self.verbose)
                time.sleep(retry + 0.25)
                continue

            if 500 <= status < 600:
                attempt += 1
                if attempt > self.max_retries:
                    raise RuntimeError(f"{status} after {attempt} retries: {body[:200]!r}")
                delay = min(2 ** attempt, 60) + random.uniform(0, 1)
                log(f"server {status}; retry {attempt}/{self.max_retries} in {delay:.1f}s",
                    verbose=self.verbose)
                time.sleep(delay)
                continue

            if status >= 400:
                raise RuntimeError(f"HTTP {status}: {body[:500]!r}")

            # Proactive rate-limit cooldown when we're at the bucket floor.
            remaining = headers.get("X-RateLimit-Remaining")
            reset_after = headers.get("X-RateLimit-Reset-After")
            if remaining == "0" and reset_after:
                try:
                    time.sleep(float(reset_after) + 0.05)
                except ValueError:
                    pass

            return json.loads(body) if body else None


def iter_channel_messages(
    client: DiscordClient,
    channel_id: str,
    *,
    start: datetime | None,
    end: datetime | None,
    users: set[str] | None,
    exclude_users: set[str] | None,
    is_thread: bool = False,
):
    """Yield messages oldest→newest within [start, end], filtered by users.

    Walks newest→oldest via `before=`, then reverses per page so output is
    chronological. Stops once we cross `start`.

    Thread starter quirk: Discord's GET /channels/{id}/messages does NOT
    include a thread's starter message (the one with msg-id == thread-id).
    When `is_thread=True`, fetch it explicitly and yield it last (after the
    pagination walk reaches the oldest paginated page).
    """
    before = str(snowflake_for(end)) if end else None
    while True:
        params = {"limit": 100}
        if before:
            params["before"] = before
        page = client.get(f"/channels/{channel_id}/messages", params)
        if not page:
            return
        page.sort(key=lambda m: int(m["id"]))  # oldest → newest
        out = []
        crossed_start = False
        for msg in page:
            ts = snowflake_timestamp(msg["id"])
            if start and ts < start:
                crossed_start = True
                continue
            if end and ts > end:
                continue
            author_id = (msg.get("author") or {}).get("id")
            if users and author_id not in users:
                continue
            if exclude_users and author_id in exclude_users:
                continue
            out.append(msg)
        for m in out:
            yield m
        if len(page) < 100:
            return
        before = str(min(int(m["id"]) for m in page))
        if crossed_start:
            return
    # unreachable — loop returns above; placeholder for thread-starter fetch
    return


def list_channel_threads(client: DiscordClient, channel_id: str) -> list[dict]:
    """Return active + archived public threads for a textual or forum channel."""
    threads: list[dict] = []
    try:
        active = client.get(f"/guilds/{{guild_id}}/threads/active")  # placeholder
    except Exception:
        active = None

    # Guild-wide active threads endpoint is the canonical one. The caller should
    # have provided guild context, but we fall back to the per-channel endpoints
    # when only a channel is available.
    try:
        archived = client.get(f"/channels/{channel_id}/threads/archived/public",
                              {"limit": 100})
        if archived and archived.get("threads"):
            threads.extend(archived["threads"])
    except Exception as e:
        log(f"archived-public lookup failed for {channel_id}: {e}", verbose=True)
    return threads


def list_guild_threads_active(client: DiscordClient, guild_id: str) -> list[dict]:
    try:
        data = client.get(f"/guilds/{guild_id}/threads/active")
        return data.get("threads", []) if data else []
    except Exception as e:
        log(f"active-threads lookup failed for guild {guild_id}: {e}", verbose=True)
        return []


def list_guild_channels(client: DiscordClient, guild_id: str) -> list[dict]:
    return client.get(f"/guilds/{guild_id}/channels") or []


def dump_to_file(
    client: DiscordClient,
    channel_id: str,
    out_path: Path,
    *,
    start: datetime | None,
    end: datetime | None,
    users: set[str] | None,
    exclude_users: set[str] | None,
    is_thread: bool = False,
) -> int:
    """Accumulate messages, sort by snowflake id (== chronological), write.

    Output is one Message JSON per line, **oldest at top** to match how the
    channel is displayed in Discord. Accumulation in memory is acceptable for
    typical Discord channels (Discord caps channels at single-digit-million
    messages and this script is meant for ad-hoc dumps).
    """
    out_path.parent.mkdir(parents=True, exist_ok=True)
    msgs: list[dict] = list(iter_channel_messages(
        client, channel_id,
        start=start, end=end, users=users, exclude_users=exclude_users,
    ))
    # Thread starter has msg-id == thread-id and isn't returned by
    # /channels/{id}/messages. Fetch explicitly and add it (id will sort first).
    if is_thread:
        try:
            starter = client.get(f"/channels/{channel_id}/messages/{channel_id}")
        except Exception as e:
            log(f"  starter fetch failed for thread {channel_id}: {e}", verbose=True)
            starter = None
        if starter:
            ts = snowflake_timestamp(starter["id"])
            in_range = (not start or ts >= start) and (not end or ts <= end)
            author_id = (starter.get("author") or {}).get("id")
            allowed = (not users or author_id in users) and \
                      (not exclude_users or author_id not in exclude_users)
            if in_range and allowed:
                msgs.append(starter)
    msgs.sort(key=lambda m: int(m["id"]))  # oldest → newest, display order
    with out_path.open("w", encoding="utf-8") as fh:
        for msg in msgs:
            fh.write(json.dumps(msg, ensure_ascii=False, separators=(",", ":")))
            fh.write("\n")
    return len(msgs)


def safe_slug(s: str) -> str:
    keep = "-_."
    return "".join(c if (c.isalnum() or c in keep) else "_" for c in s)[:80] or "x"


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        prog="discord-dump.py",
        description="Dump Discord channel/thread messages to JSON Lines.",
    )
    p.add_argument("-g", "--guild", default=os.environ.get("DISCORD_GUILD_ID"),
                   help="Guild (server) ID. Env: DISCORD_GUILD_ID")
    p.add_argument("-c", "--channel", default=os.environ.get("DISCORD_CHANNEL_ID"),
                   help="Channel ID. Required unless --all. Env: DISCORD_CHANNEL_ID")
    p.add_argument("-t", "--thread", default=os.environ.get("DISCORD_THREAD_ID"),
                   help="Specific thread ID (required if --channel is a forum and you "
                        "don't pass --forum). Env: DISCORD_THREAD_ID")
    p.add_argument("--all", action="store_true",
                   help="Dump every textual channel in the guild.")
    p.add_argument("--with-threads", action="store_true",
                   help="Also dump threads attached to the targeted channel(s) "
                        "as one jsonl per thread.")
    p.add_argument("--forum", action="store_true",
                   help="Treat --channel as a forum and dump every thread in it "
                        "(equivalent to --with-threads for forum channels).")
    p.add_argument("--start", type=parse_iso_date, default=None,
                   help="Only include messages on/after this date (UTC). YYYY-MM-DD or ISO.")
    p.add_argument("--end", type=parse_iso_date, default=None,
                   help="Only include messages on/before this date (UTC).")
    p.add_argument("--user", action="append", default=[],
                   help="Only include messages from this user ID (repeatable).")
    p.add_argument("--exclude-user", action="append", default=[],
                   help="Drop messages from this user ID (repeatable).")
    p.add_argument("--token-env", default="DISCORD_BOT_TOKEN",
                   help="Env var holding the bot token (default DISCORD_BOT_TOKEN).")
    p.add_argument("-o", "--output", required=True,
                   help="Output jsonl path. For multi-file modes, a directory.")
    p.add_argument("-v", "--verbose", action="store_true")
    p.add_argument("--max-retries", type=int, default=8)
    p.add_argument("--verify", action="store_true",
                   help="After each dump, query the API with before=<min-msg-id> "
                        "to confirm no older messages exist. For threads, also "
                        "verify the starter id is present. Exits non-zero on FAIL.")
    args = p.parse_args(argv)

    token = os.environ.get(args.token_env)
    if not token:
        print(f"error: ${args.token_env} not set", file=sys.stderr)
        return 2
    if not args.guild:
        print("error: --guild/-g is required (or DISCORD_GUILD_ID)", file=sys.stderr)
        return 2
    if not args.all and not args.channel:
        print("error: --channel/-c is required unless --all", file=sys.stderr)
        return 2

    client = DiscordClient(token, verbose=args.verbose, max_retries=args.max_retries)

    users = set(args.user) or None
    excl = set(args.exclude_user) or None
    out_arg = Path(args.output)

    def jsonl_path_for(ch: dict, parent_slug: str | None = None) -> Path:
        name = safe_slug(ch.get("name") or ch["id"])
        fname = f"{ch['id']}-{name}.jsonl"
        if parent_slug:
            return out_arg / parent_slug / fname
        return out_arg / fname

    targets: list[tuple[dict, Path]] = []

    if args.all:
        out_arg.mkdir(parents=True, exist_ok=True)
        channels = list_guild_channels(client, args.guild)
        for ch in channels:
            if ch.get("type") in (CT_GUILD_VOICE, CT_GUILD_CATEGORY, CT_GUILD_STAGE_VOICE):
                continue
            targets.append((ch, jsonl_path_for(ch)))
        if args.with_threads:
            for t in list_guild_threads_active(client, args.guild):
                targets.append((t, jsonl_path_for(t, parent_slug="threads")))
    else:
        # Need channel metadata to decide forum vs text + thread auto-discovery.
        ch = client.get(f"/channels/{args.channel}")
        if ch is None:
            print(f"error: channel {args.channel} not visible to bot", file=sys.stderr)
            return 1
        ch_type = ch.get("type")
        is_forum = ch_type in FORUM_LIKE

        if args.thread:
            tch = client.get(f"/channels/{args.thread}")
            if tch is None:
                print(f"error: thread {args.thread} not visible", file=sys.stderr)
                return 1
            single_out = out_arg if not out_arg.is_dir() and not args.with_threads else \
                jsonl_path_for(tch)
            targets.append((tch, single_out))
        elif is_forum and not (args.forum or args.with_threads):
            print("error: --channel is a forum; pass --thread, --forum, or --with-threads",
                  file=sys.stderr)
            return 2
        else:
            if not is_forum:
                # Single-channel single-file mode allowed.
                single_out = out_arg if (not args.with_threads and
                                          out_arg.suffix == ".jsonl") else \
                    jsonl_path_for(ch)
                targets.append((ch, single_out))
            if args.forum or args.with_threads or is_forum:
                # Forum or text channel with threads — discover threads.
                guild_threads = list_guild_threads_active(client, args.guild)
                for t in guild_threads:
                    if str(t.get("parent_id")) == str(args.channel):
                        targets.append((t, jsonl_path_for(t, parent_slug="threads")))
                archived = client.get(
                    f"/channels/{args.channel}/threads/archived/public",
                    {"limit": 100},
                )
                if archived:
                    for t in archived.get("threads", []):
                        targets.append((t, jsonl_path_for(t, parent_slug="threads")))

    total = 0
    any_fail = False
    for ch, path in targets:
        is_thread = ch.get("type") in THREAD_TYPES
        log(f"dumping channel {ch['id']} ({ch.get('name','?')}, type={ch.get('type')}) → {path}",
            verbose=True)
        n = dump_to_file(client, ch["id"], path,
                         start=args.start, end=args.end,
                         users=users, exclude_users=excl,
                         is_thread=is_thread)
        log(f"  wrote {n} messages", verbose=True)
        total += n
        if args.verify:
            ok = verify_dump(client, ch, path, is_thread=is_thread)
            if not ok:
                any_fail = True

    log(f"done: {total} messages across {len(targets)} channel(s)/thread(s)",
        verbose=True)
    return 1 if any_fail else 0


def verify_dump(client: DiscordClient, ch: dict, path: Path,
                *, is_thread: bool) -> bool:
    """Sanity-check a dump for completeness. Returns True on PASS."""
    min_id = None
    ids = set()
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            try:
                m = json.loads(line)
            except Exception:
                continue
            mid = int(m["id"])
            ids.add(str(m["id"]))
            if min_id is None or mid < min_id:
                min_id = mid
    if min_id is None:
        print(f"[verify] {ch['id']}: FAIL — dump is empty", file=sys.stderr)
        return False
    older = client.get(f"/channels/{ch['id']}/messages",
                      {"before": str(min_id), "limit": 100}) or []
    older_count = len(older)
    starter_ok = (not is_thread) or (str(ch["id"]) in ids)
    min_ts = snowflake_timestamp(min_id).isoformat()
    if older_count == 0 and starter_ok:
        print(f"[verify] {ch['id']} ({ch.get('name','?')}): PASS — "
              f"oldest msg {min_id} @ {min_ts}, no older messages, "
              f"starter {'present' if not is_thread else 'present'}",
              file=sys.stderr)
        return True
    if older_count > 0:
        sample = sorted(older, key=lambda m: int(m["id"]))[:3]
        sample_str = ", ".join(f"{m['id']}@{m['timestamp']}" for m in sample)
        print(f"[verify] {ch['id']}: FAIL — {older_count} older message(s) "
              f"found before {min_id}; sample: {sample_str}", file=sys.stderr)
    if is_thread and not starter_ok:
        print(f"[verify] {ch['id']}: FAIL — thread starter (id=={ch['id']}) "
              f"missing from dump", file=sys.stderr)
    return False


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
