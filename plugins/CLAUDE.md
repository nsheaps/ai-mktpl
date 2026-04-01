# Plugins Directory

This directory contains all Claude Code plugins in the marketplace. Each subdirectory is a self-contained plugin.

## Finding Things

See [how-this-repo-works](../docs/how-this-repo-works.md) for the full repo structure and conventions.

Key locations within each plugin:

- `.claude-plugin/plugin.json` — manifest (name, version, auto_discovery)
- `hooks/hooks.json` + `hooks/scripts/` — hook definitions and scripts
- `skills/` — skills (auto-discovered if `auto_discovery.skills` is set)
- `agents/` — agent definitions (auto-discovered if `auto_discovery.agents` is set)
- `commands/` — slash commands
- `rules/` — plugin-scoped rules
- `lib/` — symlinks to `../shared/lib/` for common utilities

## Creating or Modifying Plugins

- Always use `shared/lib/hook-logging.sh` for new hooks — it enforces exit 0 and standardized output
- Add a marketplace entry to `../.claude-plugin/marketplace.json` (alphabetical order)
- Match patterns from existing plugins (`common-sense`, `scm-utils`, `github-app`)

## Prefer Plugins

Per the `using-skills-and-plugins` rule: behavior changes should be encapsulated in reusable plugins, not project-specific configs. Plugins are versioned, shareable, and discoverable via the marketplace.
