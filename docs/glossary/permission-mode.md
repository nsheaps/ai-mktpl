# Permission Mode

**Definition:** How Claude Code handles tool invocation requests when no explicit allow/deny rule matches.

**Modes:**

| Mode          | Behavior                                    | Use Case                |
| ------------- | ------------------------------------------- | ----------------------- |
| `default`     | Prompts user for permission                 | Interactive development |
| `allowlist`   | Auto-denies unless explicitly allowed       | CI/CD, automation       |
| `acceptEdits` | Auto-accepts file edits, prompts for others | Trusted development     |

**CI/CD Consideration:** Always use `allowlist` mode in GitHub Actions since prompts cannot be answered.
