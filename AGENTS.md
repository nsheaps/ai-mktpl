# Repository Context for AI Assistants

> **Note:** Documentation has been distributed to `.claude/rules/` for better maintainability.

## Quick Reference

| Topic              | Location                              |
| ------------------ | ------------------------------------- |
| Plugin Development | `.claude/rules/plugin-development.md` |
| Versioning         | `.claude/rules/versioning.md`         |
| CI/CD Conventions  | `.claude/rules/ci-cd/conventions.md`  |
| Project Summary    | `.claude/CLAUDE.md`                   |

## Repository Overview

| Field          | Value                           |
| -------------- | ------------------------------- |
| **Name**       | Claude Code Plugin Marketplace  |
| **Purpose**    | Curated plugins for Claude Code |
| **Owner**      | @nsheaps                        |
| **Repository** | https://github.com/nsheaps/.ai  |

## Key Directories

| Path                 | Purpose                             |
| -------------------- | ----------------------------------- |
| `.claude/`           | Claude Code configuration and rules |
| `.claude-plugin/`    | Marketplace metadata                |
| `.github/workflows/` | CI/CD pipelines                     |
| `.github/actions/`   | Reusable composite actions          |
| `plugins/`           | Plugin implementations              |
| `docs/`              | Documentation and specs             |

## Local Development

```bash
just lint      # Run all linters
just validate  # Validate plugin structure
just check     # Run lint + validate
just plugins   # List all plugins
```

## Workflow Summary

### On Pull Requests

1. CI lints and auto-fixes issues
2. CI validates plugin structure
3. CD checks version bumps if plugins changed
4. Claude Code reviews the changes

### On Push to Main

1. CD updates marketplace.json
2. CD generates Homebrew formula
3. Changes commit with `[skip ci]`

## Current Plugins

Run `just plugins` for the current list, or see `.claude-plugin/marketplace.json`.
