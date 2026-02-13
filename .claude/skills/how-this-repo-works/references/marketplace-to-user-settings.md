# Marketplace to User Settings Propagation

Supplementary reference for the `how-this-repo-works` skill. See `../SKILL.md` for the overview.

## Marketplace Types

Claude Code supports two marketplace source types:

### Directory (local)

```json
{
  "nsheaps-claude-plugins": {
    "source": {
      "source": "directory",
      "path": "/Users/nathan.heaps/src/nsheaps/ai"
    }
  }
}
```

Claude Code reads `<path>/.claude-plugin/marketplace.json` directly from the filesystem. Updates are instant after `git pull`.

### GitHub (remote)

```json
{
  "nsheaps-claude-plugins": {
    "source": {
      "source": "github",
      "repo": "nsheaps/.ai"
    }
  }
}
```

Claude Code fetches `marketplace.json` from the GitHub repository. Updates propagate after the CD pipeline pushes to main.

## Settings Hierarchy

Plugin settings can be configured at multiple levels:

| Level | File | Scope |
|---|---|---|
| User | `~/.claude/settings.json` | All projects for this user |
| Marketplace project | `~/src/nsheaps/ai/.claude/settings.json` | When working in the marketplace repo |
| Any project | `<project>/.claude/settings.json` | Specific project |

The `enabledPlugins` map uses the format `<plugin-name>@<marketplace-name>`:

```json
{
  "enabledPlugins": {
    "scm-utils@nsheaps-claude-plugins": true,
    "todo-sync@nsheaps-claude-plugins": true,
    "git-spice@nsheaps-claude-plugins": false
  }
}
```

Setting a plugin to `false` disables it. Omitting it means it is not installed.

## Plugin Cache Structure

Installed plugins are cached at:

```
~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/<version>/
```

Example directory listing:

```
~/.claude/plugins/cache/nsheaps-claude-plugins/
  data-serialization/
  git-spice/
  product-development-and-sdlc/
  scm-utils/
    0.1.2/     # older cached version
    0.1.5/     # current version
  statusline-iterm/
    0.1.20/
  todo-sync/
```

Multiple versions may coexist. Claude Code uses the version from `marketplace.json` to select the active cache entry.

## Nathan Heaps' Specific Configuration

Nathan (GitHub: @nsheaps, email: nsheaps@gmail.com) uses the **directory** marketplace type pointing at his local clone. His propagation path is:

```
1. PR merged to main on GitHub
2. CD bumps versions + updates marketplace.json + pushes
3. Nathan runs `git pull` in ~/src/nsheaps/ai/
4. Claude Code reads updated marketplace.json from local path
5. Plugin resolves to local source path (./plugins/<name>)
6. Cache updated at ~/.claude/plugins/cache/nsheaps-claude-plugins/
7. Next Claude Code session loads the new plugin version
```

For live development (before merge), changes to plugin files in the local clone are read directly by Claude Code since the marketplace source points to the local directory. No version bump is needed for local testing.

## References

- [Claude Code Plugins Documentation](https://code.claude.com/docs/en/plugins)
- User settings: `~/.claude/settings.json`
- Marketplace project settings: `~/src/nsheaps/ai/.claude/settings.json`
