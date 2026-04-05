# Code Simplifier Plugin Research

**Date:** 2026-01-16
**Status:** Plugin implementation complete, PR #84

## Overview

This document captures research and design decisions for the `code-simplifier` plugin, which wraps the `pr-review-toolkit:code-simplifier` agent to provide on-demand code simplification capabilities.

## Architecture Decisions

### Plugin Wrapper Pattern

The plugin acts as a **thin wrapper** around an existing agent from the official Claude plugins repository (`pr-review-toolkit:code-simplifier`). This pattern:

- **Reduces duplication**: Leverages existing, maintained agent logic
- **Improves discoverability**: Exposes the capability through a dedicated `/simplify` command
- **Handles dependencies**: Guides users through installation if `pr-review-toolkit` is missing
- **Maintains session continuity**: Documents restart requirements and session resumption

### Dependency Management Approach

Rather than bundling the agent code, the plugin:

1. Checks if `pr-review-toolkit` is installed via `claude plugin list --json`
2. Guides installation if missing with scope options (user/project/local)
3. Handles the restart requirement gracefully with session resumption instructions

This keeps the plugin lightweight while leveraging the official tooling.

## Key Components

| Component                         | Purpose                                                          |
| --------------------------------- | ---------------------------------------------------------------- |
| `skills/code-simplifier/SKILL.md` | Documentation and trigger phrases for automatic skill invocation |
| `commands/simplify.md`            | `/simplify` slash command with dependency checking logic         |
| `README.md`                       | Installation guide and usage examples                            |
| `.claude-plugin/plugin.json`      | Plugin manifest with metadata                                    |

## Trigger Phrases

The skill activates on phrases like:

- "simplify code"
- "clean up code"
- "refactor for clarity"
- "reduce complexity"
- "make code more readable"

## CLI Commands Reference

| Task                    | Command                                                                                 |
| ----------------------- | --------------------------------------------------------------------------------------- |
| Check dependency        | `claude plugin list --json \| jq '.[] \| select(.id \| contains("pr-review-toolkit"))'` |
| Install (user scope)    | `claude plugin install pr-review-toolkit@claude-plugins-official`                       |
| Install (project scope) | `claude plugin install pr-review-toolkit@claude-plugins-official --scope project`       |
| Resume session          | `claude --continue`                                                                     |
| Resume by ID            | `claude --resume $SESSION_ID`                                                           |

## Session Handling

Plugins load at session start. When installing a new plugin dependency:

1. Note current session ID (via `/session`)
2. Install the plugin via CLI
3. Wait ~15 seconds for potential hot-reload
4. If agent still unavailable, restart with `claude --continue`

The `/simplify` command handles this flow automatically with user prompts.

## Related Concepts

### Drill-Down Documentation

This plugin uses the **drill-down docs** pattern where:

- High-level usage is in `README.md`
- Detailed implementation is in `skills/*/SKILL.md`
- Troubleshooting and CLI reference are linked from the command file

### One-Shot Agent Execution

The code-simplifier is designed for one-shot execution:

1. Receives specific scope (file, description, or recent changes)
2. Performs analysis and refactoring
3. Reports results
4. Session completes

This pattern is ideal for CI/CD integration where a GitHub Action can invoke simplification on PR code.

## References

- [PR #84 - Plugin Implementation](https://github.com/nsheaps/ai-mktpl/pull/84)
- [pr-review-toolkit Plugin](https://github.com/anthropics/claude-plugins-official)
- [Claude Code Plugin Development Guide](https://docs.anthropic.com/en/docs/claude-code/plugins)
