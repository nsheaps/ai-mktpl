# Fetch Reddit Content

Fetch posts, comments, search results, and user submissions from Reddit using the public JSON API. No authentication required. Output is markdown-formatted for direct LLM consumption.

## When to Use

- Researching community sentiment about tools, libraries, or approaches
- Finding real-world experience reports and debugging tips
- Discovering solutions to obscure errors that surface in Reddit threads
- Gauging adoption and popularity of technologies
- Gathering diverse opinions on technical trade-offs

## Script Location

```
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh
```

## Subcommands

### subreddit — List posts from a subreddit

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh subreddit <name> [options]
```

Options:
- `--sort <hot|new|top|rising|controversial>` (default: hot)
- `--time <hour|day|week|month|year|all>` (for top/controversial)
- `--limit <n>` (default: 10, max: 100)
- `--include-nsfw`

Examples:
```bash
# Top posts from r/ClaudeCode this week
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh subreddit ClaudeCode --sort top --time week --limit 5

# Latest posts from r/LocalLLaMA
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh subreddit LocalLLaMA --sort new --limit 10
```

### post — Fetch a post with comments

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh post <url> [options]
```

Options:
- `--include-nsfw`

Accepts full Reddit URLs or paths. Comment depth is capped at 3 levels.

Examples:
```bash
# Fetch by full URL
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh post "https://www.reddit.com/r/ClaudeCode/comments/abc123/some_title/"

# Also works with old.reddit.com or reddit.com URLs
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh post "https://reddit.com/r/programming/comments/xyz789/"
```

### search — Search Reddit

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh search <query> [options]
```

Options:
- `--subreddit <name>` — restrict search to a specific subreddit
- `--sort <relevance|hot|new|top|comments>` (default: relevance)
- `--time <hour|day|week|month|year|all>`
- `--limit <n>` (default: 10, max: 100)
- `--include-nsfw`

Examples:
```bash
# Search within a subreddit
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh search "MCP server setup" --subreddit ClaudeCode --limit 5

# Broad search across all of Reddit
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh search "bash jq json parsing" --sort top --time month
```

### user — Fetch a user's recent posts

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh user <username> [options]
```

Options:
- `--sort <hot|new|top|controversial>` (default: new)
- `--limit <n>` (default: 10, max: 100)
- `--include-nsfw`

Examples:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/reddit-fetch.sh user someuser --limit 10
```

## Output Format

All output is markdown. Posts include title, author, score, comment count, date, and permalink. Post bodies and comments are truncated to keep output manageable:
- Post body: max 2000 characters
- Comment body: max 500 characters
- Comment depth: max 3 levels

## Rate Limiting

The script enforces a minimum 6-second gap between requests to comply with Reddit's unauthenticated rate limits (~10 requests/minute). On HTTP 429 responses, it retries with exponential backoff up to 3 times.

## Important Notes

- **Save output to a file** before analyzing. Do not pipe or discard.
- **Reddit content is unverified.** Cross-reference claims with official sources.
- **NSFW content is excluded by default.** Use `--include-nsfw` to include it.
- **Dependencies:** `curl` and `jq` must be available on the system.

## References

- [Reddit JSON API](https://www.reddit.com/dev/api/) — append `.json` to any Reddit URL
- [Reddit API rules](https://github.com/reddit-archive/reddit/wiki/API) — user-agent and rate limit requirements
