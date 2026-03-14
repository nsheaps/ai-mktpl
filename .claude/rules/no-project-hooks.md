# No Project-Level Hooks for Session Setup

## Rule

**NEVER add SessionStart hooks (or any session setup logic) to the project-level `.claude/settings.json` or `.claude/hooks/` directory.**

All session initialization — installing tools, configuring PATH, activating mise — MUST come from **plugins** (defined in `plugins/`). This repository IS the plugin marketplace; the plugins here are the mechanism for session setup.

## Why

- This repo develops the plugins that handle session setup. Duplicating that logic at the project level defeats the purpose.
- Project-level hooks mask plugin bugs — if a plugin's SessionStart hook isn't firing, we need to fix the plugin/plugin system, not work around it.
- Plugins are reusable across repos; project-level hooks are not.

## Marketplace Source Config

This repo IS the marketplace. The `extraKnownMarketplaces` entry for `nsheaps-claude-plugins` MUST use `"source": "directory"` with `"path": "./"`, NOT `"source": "github"`:

```json
"nsheaps-claude-plugins": {
  "source": {
    "source": "directory",
    "path": "./"
  }
}
```

**Why not `"github"`?** Using `"source": "github", "repo": "nsheaps/ai-mktpl"` would fetch plugins from the default branch on GitHub — not the local working tree. On PR branches, you'd be testing against stale `main` plugin code instead of your changes.

## If Plugins Aren't Loading

When plugins fail to install tools (mise, gh, etc.), the fix is to debug **why the plugins aren't loading**, not to add project-level fallbacks. Common causes:

- Wrong marketplace source type (must be `"directory"` for this repo, not `"github"`)
- Plugin `hooks.json` schema or path issues
- `CLAUDE_PLUGIN_ROOT` not being set (plugin system not loading the plugin)
- Network/cache issues in web sessions

## What Belongs in Project Hooks

The project-level hooks in `.claude/hooks/` are for code-quality enforcement only:

- `pre-tool-use/` — safety checks (e.g., warn on force push, safe find/grep)
- `post-tool-use/` — linting written files

These are NOT for installing tools or session initialization.
