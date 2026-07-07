# Message Link Formatting

**Every reference to a PR, issue, ticket, commit, chat message, or other external resource that CAN be referenced by a URL MUST be a clickable (usually markdown) link.**

## Rule

When mentioning artifacts and resources in messages, always use the full markdown link format:

| Artifact      | Format                                                                                                                       | Example                                                                                                             |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| PR            | `[PR repo-name#N](url)`                                                                                                      | [PR repo-name#458](https://github.com/nsheaps/repo-name/pull/458)                                                   |
| Issue         | `[repo-name#N](url)` OR `[nsheaps/repo-name#N](url)` (org can be skipped if personal org, or if most repos share common org) | [nsheaps/repo-name#40](https://github.com/nsheaps/repo-name/issues/40)                                              |
| Ticket        | `[ABC-123](url)`                                                                                                             | [ABC-123](https://linear.app/org-name/issue/ABC-123) (or other relevant ticketing platform like Jira or ServiceNow) |
| Commit        | ```[`repo-name@abc1234`](url)```                                                                                               | [`repo-name@dcffa5a`](https://github.com/nsheaps/reponame/commit/dcffa5a)                                                     |
| External link | `[description](url)`                                                                                                         | [how to be awesome](https://github.com/anthropics/claude-code/wiki/being-awesome)                                   |

## Anti-Patterns

| Bad                                             | Good                                                                                                      |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `PR #458 fixes the duplicate hooks`             | `[PR repo-name#458](https://github.com/nsheaps/repo-name/pull/458) fixes the duplicate hooks`             |
| `Fixed in commit dcffa5a`                       | `Fixed in [\`repo-name@dcffa5a\`](https://github.com/nsheaps/repo-name/commit/dcffa5a)`                   |
| `See issue 40`                                  | `See [repo-name#40](https://github.com/nsheaps/repo-name/issues/40)`                                      |
| `https://github.com/nsheaps/repo-name/pull/458` | `[PR repo-name#458](https://github.com/nsheaps/repo-name/pull/458)`                                       |
| `ABC-123`                                       | `[ABC-123](https://orgname.atlassian.net/browse/ABC-123)`                                                 |
| `INC0048316`                                    | `[ABC-123](https://orgname.service-now.com/nav_to.do?uri=task_list.do?sysparm_query=number%3DINC0048316)` |

## Why

- Bare text references are not clickable — the user has to construct the URL themselves or dig into references elsewhere
- Bare URLs are ugly and hard to scan in a message
- Markdown links are compact, clickable, and convey both the reference and the destination
- This applies to ALL sent messages, whether chat (like in the gleam app or slack), email, git commit messages, pr body, etc. Wherever possible it should be linked using the formatting appropriate for that platform
