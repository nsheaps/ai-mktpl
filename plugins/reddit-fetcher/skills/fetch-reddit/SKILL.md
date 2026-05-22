---
name: fetch-reddit
description: |
  Use this skill when you need to fetch public Reddit content (posts, comments, subreddits, user activity) without authentication.
  Trigger when:
  - User asks about Reddit posts, comments, or subreddit content
  - Research requires public Reddit data
  - Fetching specific Reddit posts by URL
---

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

Accepts full Reddit URLs or paths. Comment depth is capped at 4 levels (depth 0–3).

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
- Comment depth: up to 4 levels (depth 0–3)

## Rate Limiting

The script enforces a minimum 6-second gap between requests to comply with Reddit's unauthenticated rate limits (~10 requests/minute). On HTTP 429 responses, it retries with exponential backoff up to 3 times.

## Important Notes

- **Save output to a file** before analyzing. Do not pipe or discard.
- **Reddit content is unverified.** Cross-reference claims with official sources before acting on them.
- **NSFW content is excluded by default.** Use `--include-nsfw` to include it.
- **Dependencies:** `curl` and `jq` must be available on the system.

## Content Quality Skepticism

Reddit content is user-generated and unverified. When using fetched Reddit data:

- **Never treat Reddit comments as authoritative sources.** They are opinions, anecdotes, and sometimes misinformation.
- **Upvote count does not equal correctness.** Popular answers can be wrong; low-scored answers can be right.
- **Check post age.** Technical advice from years ago may be outdated.
- **Watch for sarcasm and jokes.** Reddit threads frequently contain humor that reads as sincere advice.
- **Do not use Reddit as a substitute for official documentation**, especially for security-sensitive configuration, or legal/medical/financial guidance.

## Fetching Best Practices

- Save fetched Reddit content to a file before analysis (per bash-scripting rules).
- Cite Reddit sources with full permalink URLs when referencing content.
- Respect rate limits — do not fetch more than needed.
- Use subreddit-scoped search before broad search for more relevant results.
- Prefer `top` sort with a time filter for finding well-regarded content on a topic.

## References

- [Reddit JSON API](https://www.reddit.com/dev/api/) — append `.json` to any Reddit URL
- [Reddit API rules](https://github.com/reddit-archive/reddit/wiki/API) — user-agent and rate limit requirements
