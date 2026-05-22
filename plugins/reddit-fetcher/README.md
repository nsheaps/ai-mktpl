# reddit-fetcher

Fetch Reddit posts, comments, and subreddit listings via Reddit's public JSON API. Returns markdown-formatted content suitable for LLM consumption. No authentication required.

## Installation

Add this plugin through the ai-mktpl marketplace or install directly:

```bash
claude plugin add --from https://github.com/nsheaps/ai-mktpl --path plugins/reddit-fetcher
```

## Dependencies

- `curl` — HTTP requests
- `jq` — JSON parsing

Both are commonly pre-installed on Linux and macOS.

## Usage

The plugin provides a skill (`fetch-reddit`) that documents all available subcommands. Invoke via the skill or call the script directly:

```bash
# List hot posts from a subreddit
reddit-fetch.sh subreddit programming --limit 5

# Fetch a specific post with comments
reddit-fetch.sh post "https://www.reddit.com/r/ClaudeCode/comments/abc123/title/"

# Search Reddit
reddit-fetch.sh search "error handling best practices" --subreddit golang --sort top --time month

# View a user's recent posts
reddit-fetch.sh user someuser --limit 10
```

### Subcommands

| Subcommand         | Description                                                          |
| ------------------ | -------------------------------------------------------------------- |
| `subreddit <name>` | List posts from a subreddit (hot, new, top, rising, controversial)   |
| `post <url>`       | Fetch a single post with its comment tree (depth capped at 4 levels) |
| `search <query>`   | Search all of Reddit or a specific subreddit                         |
| `user <username>`  | Fetch a user's recent submitted posts                                |

### Common Options

| Option           | Description                       | Default             |
| ---------------- | --------------------------------- | ------------------- |
| `--sort`         | Sort order (varies by subcommand) | `hot` / `relevance` |
| `--time`         | Time filter for top/controversial | none                |
| `--limit`        | Number of results (max 100)       | 10                  |
| `--include-nsfw` | Include NSFW posts                | excluded            |

## Rate Limiting

The script enforces a 6-second minimum gap between requests to respect Reddit's unauthenticated rate limits. HTTP 429 responses trigger automatic retries with backoff (up to 3 attempts).

## Output Format

All output is markdown, optimized for LLM consumption:

- Post bodies are truncated at 2000 characters
- Comments are truncated at 500 characters
- Comment nesting is capped at 4 levels deep (depth 0–3)
- NSFW posts are excluded by default

## Content Quality Warning

Reddit content is user-generated and unverified. Always cross-reference technical claims with official documentation. See the `fetch-reddit` skill for detailed content quality guidelines.

## Design Decisions

- **Bash + curl + jq** over Node.js/Python: zero additional dependencies, follows ai-mktpl conventions
- **No authentication**: public JSON API is sufficient for read-only access to all public content
- **Skill-based** over MCP server: simpler, no daemon management, rate limiting handled naturally by sequential calls
- **Markdown output** over JSON: directly consumable by LLMs without additional parsing

## References

- [Reddit JSON API](https://www.reddit.com/dev/api/)
- [Reddit API rules](https://github.com/reddit-archive/reddit/wiki/API)
- [ClawHub reddit-readonly](https://clawhub.ai/buksan1950/reddit-readonly) — inspiration for the direct JSON API approach
