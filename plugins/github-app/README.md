# github-app

env-var driven GitHub App token lifecycle for Claude Code sessions.

GitHub App installation tokens expire after 1 hour. This plugin generates tokens on session start and monitors their validity via a PreToolUse hook, refreshing transparently before commands that need authentication.

## Features

- **SessionStart hook**: Reads credentials from env vars, materializes PEM, generates installation token, configures git identity, exports credentials via runtime env file
- **PreToolUse hook**: Debounced/throttled token validity checks with smart sync/async refresh
- **Git credential helper**: Seamless `git push` / `gh` auth via shared token file
- **Per-agent isolation**: All files written under `$CLAUDE_PLUGIN_DATA/` — each agent automatically gets its own isolated directory
- **Manual-operation skills**: Every hook operation (token lifecycle, session env wiring, bot git identity) has a skill so it can be reproduced by hand when a hook doesn't run
- **Hook-driven event delivery**: GitHub events delivered at session start, on each user prompt, and polled while the session is stopping — configurable via `eventsDelivery` (see [GitHub Events Delivery](#github-events-delivery))
- **CLI events watcher**: `bin/events-monitor.sh` polls the GitHub events REST API manually as the App, emits one line per new event (see [Manual Events Monitor](#manual-events-monitor))
- **Authentication skill**: Shared with `github` plugin — covers all auth methods

## Setup

### 1. Create a GitHub App

1. Go to `https://github.com/settings/apps/new`
2. Set a name and homepage URL
3. Configure permissions (Contents: Read & Write, Pull Requests: Read & Write, etc.)
4. Generate a private key and download the PEM file

### 2. Install the App

1. Install the App on the target account or organization
2. Note the installation ID from the URL: `https://github.com/settings/installations/<ID>`

### 3. Configure Credentials

Set these three env vars before the session starts:

- `GITHUB_APP_ID`
- `GITHUB_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY` (PEM content — not a file path)

**Recommended**: Use the **1pass plugin** to inject from 1Password. Add to your agent's `plugins.settings.yaml`:

```yaml
1pass:
  secrets:
    - envVar: GITHUB_APP_ID
      reference: "op://vault/github-app--repo--my-repo/GITHUB_APP_ID"
    - envVar: GITHUB_INSTALLATION_ID
      reference: "op://vault/github-app--repo--my-repo/GITHUB_INSTALLATION_ID"
    - envVar: GITHUB_APP_PRIVATE_KEY
      reference: "op://vault/github-app--repo--my-repo/GITHUB_APP_PRIVATE_KEY"

github-app:
  enabled: true
  autoGitConfig: true
```

Any mechanism that exports these vars into the session env works (direct export, `.env` file sourced before launch, etc.). The 1pass plugin is simply the recommended approach.

## How It Works

1. **Session starts**: Hook reads three env vars, materializes PEM to `$CLAUDE_PLUGIN_DATA/github-app.pem`
2. **Token generated**: JWT created from PEM, exchanged for installation token via GitHub API
3. **Token stored**: Written to `$CLAUDE_PLUGIN_DATA/github-token` (mode 600)
4. **Git identity configured**: Sets `GIT_AUTHOR_*`/`GIT_COMMITTER_*` to the App's bot identity (e.g., `my-app[bot]`). Controlled by `autoGitConfig: true` (default).
5. **Runtime env file**: `GH_TOKEN` and `GITHUB_TOKEN` written to `$CLAUDE_PLUGIN_DATA/github-app-env`, sourced by `CLAUDE_ENV_FILE`
6. **PreToolUse monitoring**: Before each tool call, checks token expiry (debounced to every 5 min)
7. **Smart refresh**: Commands using `gh`/`git push` get synchronous checks; others get async background refresh
8. **Retry with backoff**: Failed refreshes retry up to 3 times, then back off for 5 minutes

### Token Refresh Behavior

| Scenario                                          | Behavior                                |
| ------------------------------------------------- | --------------------------------------- |
| Token valid, >45 min remaining                    | Silent, no action                       |
| Token valid, <45 min remaining, non-token command | Background refresh                      |
| Token valid, <45 min remaining, gh/git command    | Allow + background refresh              |
| Token expired, gh/git command                     | Synchronous refresh before allowing     |
| Token expired, non-token command                  | Background refresh                      |
| Refresh fails                                     | Retry up to 3x with exponential backoff |
| All retries fail                                  | 5-minute cooldown, then retry           |

## Configuration

```yaml
github-app:
  enabled: true
  autoGitConfig: true
  # How long SessionStart waits for env vars to appear (seconds).
  # Set to 0 to disable.
  waitForEnvTimeoutSeconds: 15

  # --- Hook-driven event delivery ---
  # eventsDelivery modes: disabled (default) | file | user | both | summary
  eventsDelivery: "disabled"
  eventsRepo: "" # owner/repo to watch (required for any delivery)
  eventsPollIntervalSeconds: 15
  eventsStopTimeoutSeconds: 600  # max seconds to poll during Stop before allowing exit
  eventsStopNoticeSeconds: 480   # seconds before emitting "no events received" notice
```

## GitHub Events Delivery

The plugin delivers GitHub events through Claude Code hooks at key lifecycle points. This replaces the previous `experimental.monitors` auto-start approach, which only worked for user-scope plugins.

### Enabling delivery

Set `eventsDelivery` and `eventsRepo` in your `plugins.settings.yaml`:

```yaml
github-app:
  eventsRepo: "owner/repo"
  eventsDelivery: "summary"  # or: user, both, file
```

### Delivery modes

| Mode | Audit log | User (`systemMessage`) | Claude (`additionalContext`) |
| --- | --- | --- | --- |
| `disabled` (default) | — | — | — |
| `file` | yes | — | — |
| `user` | yes | full event list | — |
| `both` | yes | full event list | full event list |
| `summary` | yes | `events received from github` | full event list |

The audit log is always written to `$CLAUDE_PLUGIN_DATA/events-delivery.log` for all non-disabled modes.

### Hook lifecycle

| Hook | Matcher | Behavior |
| --- | --- | --- |
| `SessionStart` | `startup` | Shows the **last 10** events; sets cursor baseline |
| `SessionStart` | `resume` | Shows events since last fetch (cursor-based) |
| `UserPromptSubmit` | `*` | Shows events since last fetch; async + rewakes Claude if any |
| `Stop` | `*` | Polls up to `eventsStopTimeoutSeconds`; rewakes on new events |

**Stop hook behavior**: The Stop hook runs asynchronously while Claude is preparing to stop. It polls the events API every `eventsPollIntervalSeconds` seconds:
- If new events arrive: delivers them and rewakes Claude (exit 2)
- At `eventsStopNoticeSeconds` with no events: emits `no github events received in the last <X>` and rewakes
- At `eventsStopTimeoutSeconds`: allows stop (exit 0)

**Claude-facing messages** always begin with: `not every event may be related to your current working task`

> **Note on async/rewake:** The `UserPromptSubmit` and `Stop` hooks use `async: true` + `asyncRewake: true`. These fields are documented in the design notes as `[VERIFY]` — interactive session validation is needed to confirm the rewake mechanism behaves as expected.

### Event ordering note

GitHub event ids are not monotonic across event types (e.g. `PullRequestReviewEvent` ids sit in a lower range than `PushEvent` ids). The cursor stores the id of the newest event seen and relies on the API's reverse-chronological ordering — emitting everything above that id in the page (oldest-first), then recording the new top id.

### State files

| File | Purpose |
| --- | --- |
| `events-hook-state.json` | Cursor (last seen id), last-fetch timestamp, Stop hook state |
| `events-delivery.log` | Append-only audit log of all deliveries |

## Manual Events Monitor

`bin/events-monitor.sh` is a long-running CLI watcher (not a hook). Use it via the `Monitor` tool, cron, or directly when you want a real-time event feed.

```bash
# Watch a repo's events every 15s (default interval)
events-monitor.sh --repo nsheaps/.ai-agent-jack

# Custom interval, single poll (useful for cron / testing)
events-monitor.sh --repo owner/repo --interval 30
events-monitor.sh --repo owner/repo --once

# Other event feeds via --api-path (org / user / public / network)
events-monitor.sh --api-path /orgs/nsheaps/events --interval 60
events-monitor.sh --api-path /users/some-user/events
```

**Configuration** (precedence: CLI flag > env var > plugin setting > default):

| Setting       | CLI flag        | Env var                         | Plugin setting              | Default                     |
| ------------- | --------------- | ------------------------------- | --------------------------- | --------------------------- |
| Poll interval | `--interval`    | `GITHUB_APP_EVENTS_INTERVAL`    | `eventsPollIntervalSeconds` | `15`                        |
| Repo to watch | `--repo`        | `GITHUB_APP_EVENTS_REPO`        | `eventsRepo`                | —                           |
| API path      | `--api-path`    | `GITHUB_APP_EVENTS_API_PATH`    | —                           | derived                     |
| Page size     | `--per-page`    | `GITHUB_APP_EVENTS_PER_PAGE`    | —                           | `50`                        |
| Cursor file   | `--cursor-file` | `GITHUB_APP_EVENTS_CURSOR_FILE` | —                           | under `$CLAUDE_PLUGIN_DATA` |

**Output split**:

- **stdout** (each line is a Monitor notification):
  - one line per new event: `[<created_at>] <EventType> by <actor> on <owner/repo> (id <event_id>)`
  - `[error]` lines (rate limit, auth, token-refresh failure), de-duplicated
- **stderr** (operational log): `[start]`, `[baseline]`, and `[token]` (emitted only when `token-check.sh` rotates the token).

The monitor uses its own cursor file (separate from the hook-state cursor) so it can run alongside hook-driven delivery without interference.

### Known limitations

- **Single-page polling.** Each poll fetches one page (`--per-page`, default 50) and advances the cursor to that page's newest id. If more than `per_page` new events land in a single interval, the overflow (oldest) events are skipped. Pagination is intentionally omitted to keep the monitor simple.

## On-disk Layout

All files are written under `$CLAUDE_PLUGIN_DATA/` (per-agent isolated automatically):

```
$CLAUDE_PLUGIN_DATA/
├── github-app.pem            # Materialized PEM (mode 600, rewritten each SessionStart)
├── github-token              # Raw token (mode 600)
├── github-token.meta         # JSON: expires_at, app_id, installation_id, app_slug, bot_id
├── github-token.cooldown     # After 3 failed retries (5-min backoff)
├── github-token.lock         # Mutex for concurrent refresh
├── github-app-env            # Runtime env file sourced via CLAUDE_ENV_FILE
├── github-git-identity       # Stable identity file (not overwritten by token refresh)
├── github-app-last-check     # Debounce timestamp
├── events-hook-state.json    # Hook delivery state: cursor (last_seen_id), last_fetch_ts, Stop state
├── events-delivery.log       # Append-only audit log of hook-delivered events
├── events-cursor-*           # events-monitor.sh cursor (per feed, independent of hook state)
├── gh/                       # Isolated GH_CONFIG_DIR
└── git/config                # Isolated GIT_CONFIG_GLOBAL target
```

## Plugin Structure

```
plugins/github-app/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── github-token-init.sh     # SessionStart: credential check, PEM materialization, token + env setup
│       └── github-token-check.sh    # PreToolUse: debounced validity check
├── skills/
│   ├── github-auth/SKILL.md         # Shared auth skill (symlink)
│   ├── github-app-token/SKILL.md    # Token lifecycle: generate, refresh, status
│   ├── github-app-session-env/SKILL.md   # Manual session env wiring (PEM, env file, CLAUDE_ENV_FILE, GH_CONFIG_DIR)
│   └── github-app-git-identity/SKILL.md  # Manual bot git identity + gh credential helper
├── bin/
│   ├── generate-token.sh            # JWT generation + token exchange
│   ├── token-check.sh               # Token validity check + refresh logic
│   ├── token-status.sh              # Token status JSON output
│   ├── events-lib.sh                # Shared fetch/cursor/delivery library (sourced by monitor + fetch)
│   ├── events-fetch.sh              # One-shot hook entrypoint (session-start, user-prompt, stop)
│   └── events-monitor.sh            # Long-running CLI watcher; sources events-lib.sh
├── lib/
│   ├── env-file.sh                  # Runtime env file writer
│   ├── token-utils.sh               # Token expiry helpers
│   └── wait-for-env.sh              # Poll CLAUDE_ENV_FILE for vars
├── docs/
│   └── reference/                   # Archived implementations
└── README.md
```

## Upgrading from 0.3.x

### Breaking changes in v0.4.0

- **Env-var contract simplified**: Only `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY` are read. The `GITHUB_APP_PRIVATE_KEY_PATH` input var is gone — provide PEM content directly.
- **`ref:` and `secrets.*` settings removed**: The plugin no longer resolves secrets from 1Password directly. Use the 1pass plugin's `secrets:` list instead.
- **Paths moved**: All runtime files now live under `$CLAUDE_PLUGIN_DATA/` instead of `~/.agents/<name>/.config/`.

### Migration

Update your agent's `plugins.settings.yaml`:

```yaml
# Before (v0.3.x):
github-app:
  ref: 'op://vault/github-app--repo--my-repo'

# After (v0.4.0):
github-app:
  enabled: true
  autoGitConfig: true

1pass:
  secrets:
    - envVar: GITHUB_APP_ID
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_APP_ID'
    - envVar: GITHUB_INSTALLATION_ID
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_INSTALLATION_ID'
    - envVar: GITHUB_APP_PRIVATE_KEY
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_APP_PRIVATE_KEY'
```

After the first session start on v0.4.0, old files at `~/.agents/<name>/.config/` become orphaned and can be cleaned up:

```bash
rm -rf ~/.agents/<name>/.config/github-token* ~/.agents/<name>/.config/github-app-env \
       ~/.agents/<name>/.config/github-app.pem ~/.agents/<name>/.config/github-git-identity
```

### Git credential helper

The credential helper configuration is unchanged from v0.3.x:

```ini
[credential "https://github.com"]
    helper =
    helper = !gh auth git-credential
```

## Related

- **[github](../github)** plugin — GitHub CLI installation, usage skill, and general auth

## Security

- PEM is materialized from `$GITHUB_APP_PRIVATE_KEY` on every session start — never cached across sessions
- Token file and runtime env file are written with mode 600
- Installation tokens are scoped to the App's configured permissions
- Tokens expire after 1 hour (non-extensible) and are refreshed automatically
- File-based locking prevents concurrent refresh races
