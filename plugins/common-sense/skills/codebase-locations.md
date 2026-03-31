---
name: codebase-locations
description: "Standard Claude Code project file locations. Use before searching for artifacts (agents, skills, commands, hooks, rules, plugins, etc.) to ensure all standard directories are checked."
---

# Standard Claude Code File Locations

When searching for Claude Code artifacts in a repository, check ALL of these standard locations. Missing even one can cause search failures.

## Per-Project Locations (relative to repo root)

| Directory                    | Contains                                                |
| ---------------------------- | ------------------------------------------------------- |
| `.claude/agents/`            | Agent definitions (`.md` files with YAML frontmatter)   |
| `.claude/skills/`            | Skill files (`.md` with frontmatter)                    |
| `.claude/commands/`          | Slash command files (`.md`)                             |
| `.claude/rules/`             | Rule files (`.md`)                                      |
| `.claude/hooks/`             | Hook configurations                                     |
| `.claude/memory/`            | Memory files                                            |
| `.claude/plans/`             | Implementation plans                                    |
| `.claude/scratch/`           | Working notes                                           |
| `.claude/tmp/`               | Temporary files                                         |
| `.claude/docs/`              | Agent documentation                                     |
| `.claude/contacts/`          | Contact files                                           |
| `.claude/prompts/`           | Saved prompts                                           |
| `.claude-plugin/`            | Plugin manifest directory                               |
| `.claude-plugin/plugin.json` | Plugin manifest                                         |
| `plugins/*/`                 | Plugin source directories (in marketplace repos)        |
| `docs/specs/`                | Specifications (draft/, reviewed/, in-progress/, live/) |
| `docs/research/`             | Research findings                                       |

## Plugin Locations (relative to plugin root)

| Directory                    | Contains                 |
| ---------------------------- | ------------------------ |
| `hooks/hooks.json`           | Hook configuration       |
| `hooks/scripts/`             | Hook scripts             |
| `skills/`                    | Plugin skills            |
| `agents/`                    | Plugin agent definitions |
| `commands/`                  | Plugin commands          |
| `rules/`                     | Plugin rules             |
| `lib/`                       | Shared library scripts   |
| `.claude-plugin/plugin.json` | Plugin manifest          |

## User-Level Locations

| Directory                  | Contains                            |
| -------------------------- | ----------------------------------- |
| `~/.claude/agents/`        | User-level agent definitions        |
| `~/.claude/skills/`        | User-level skills                   |
| `~/.claude/commands/`      | User-level commands                 |
| `~/.claude/rules/`         | User-level rules                    |
| `~/.claude/plugins/`       | Installed plugins                   |
| `~/.claude/plugins/cache/` | Plugin cache (marketplace installs) |

## Search Strategy

When looking for a specific artifact type:

1. **Check the project's `.claude/` directory first** -- this is the most common location
2. **Check `plugins/*/` if in a marketplace repo** -- plugins have their own subdirectories
3. **Check user-level `~/.claude/`** -- some artifacts are user-scoped
4. **Check installed plugin caches** -- `~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/`
5. **Use glob patterns** like `**/.claude/agents/*.md` to search recursively

## Common Mistakes

- Only searching `plugins/*/skills/` and missing `.claude/agents/`
- Only searching top-level directories and missing nested plugin structures
- Forgetting user-level paths in `~/.claude/`
- Not checking plugin cache directories for installed artifacts
