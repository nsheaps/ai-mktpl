# Message Link Formatting

**Every reference to a PR, issue, ticket, commit, chat message, or other external resource that CAN be referenced by a URL MUST be a clickable markdown link.**

## Rule

When mentioning artifacts in channel messages, always use the full markdown link format:

| Artifact      | Format                                 | Example                                                               |
| ------------- | -------------------------------------- | --------------------------------------------------------------------- |
| PR            | `[PR repo-name#N](url)`                | [PR repo-name#458](https://github.com/nsheaps/repo-name/pull/458)               |
| Issue         | `[repo-name#N](url)`  OR `[nsheaps/repo-name#N](url)`                | [nsheaps/repo-name#40](https://github.com/nsheaps/repo-name/issues/40)            |
| Commit        | `repo-name@[\`abc1234\`](url)`                   | [`dcffa5a`](https://github.com/nsheaps/reponame/commit/dcffa5a)       |
| External link | `[description](url)`                   | [upstream bug](https://github.com/anthropics/claude-code/issues/6305) |

## Anti-Patterns

| Bad                                            | Good                                                                                |
| ---------------------------------------------- | ----------------------------------------------------------------------------------- |
| `PR #458 fixes the duplicate hooks`            | `[PR repo-name#458](https://github.com/nsheaps/repo-name/pull/458) fixes the duplicate hooks` |
| `Fixed in commit dcffa5a`                      | `Fixed in [\`dcffa5a\`](https://github.com/nsheaps/ai-mktpl/commit/dcffa5a)`        |
| `See issue 40`                                 | `See [repo-name#40](https://github.com/nsheaps/repo-name/issues/40)`                    |
| `https://github.com/nsheaps/repo-name/pull/458` | `[PR repo-name#458](https://github.com/nsheaps/repo-name/pull/458)`                           |

## Why

- Bare text references are not clickable — the handler has to manually construct the URL
- Bare URLs are ugly and hard to scan in a message
- Markdown links are compact, clickable, and convey both the reference and the destination
- This applies to ALL channel messages, not just completion reports (artifact-linking-in-reports covers those separately)

## Applies To

- All Discord messages
- All Telegram messages
- PR thread comments
- Any external communication where the handler reads the message

Source: Handler correction (2026-04-28) — "Jack where is my PR link why are you not formatting messages correctly again"
