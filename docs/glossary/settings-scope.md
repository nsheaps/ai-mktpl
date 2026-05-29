# Settings Scope

**Definition:** The level at which a configuration option applies, determining visibility and override behavior.

**Claude Code Scopes:**

| Scope   | Location                      | Visibility                 | Git Tracked     |
| ------- | ----------------------------- | -------------------------- | --------------- |
| User    | `~/.claude/settings.json`     | All projects for user      | No              |
| Project | `.claude/settings.json`       | All users of project       | Yes             |
| Local   | `.claude/settings.local.json` | Current user, this project | No (gitignored) |

**Precedence (highest to lowest):**

1. Managed settings (system-level)
2. Command line arguments
3. Local project settings
4. Shared project settings
5. User settings

**See also:** [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)
