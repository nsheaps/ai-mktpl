# Plugin Hierarchy

## Selection Priority

When choosing plugins for the generated prompt, follow this strict priority order:

1. **`nsheaps/ai-mktpl`** — First choice. Always check here first.
2. **`anthropics/claude-plugins-official`** — Second choice. Anthropic's curated directory.
3. **`anthropics/claude-code`** — Third choice. Bundled with Claude Code itself.
4. **Custom (project-defined)** — Last resort. Only for project-specific logic no plugin covers.

If two marketplaces offer equivalent functionality, prefer the higher-priority source.

## nsheaps/ai-mktpl — Complete Plugin Inventory

### Always-Include (every project)

| Plugin                 | Type              | What It Does                                                                                                                                                                                                                                                                                                                                                        |
| ---------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scm-utils`            | commands + skills | Code review (`/code-review`), commit (`/commit`), branch update (`/update-branch`). Skills: code-review (with copilot-style instructions, labels, prompt templates, workflow templates), commit message generation, git-worktree management, iterate-until-good loop, branch update with conflict resolution. Hooks: check for uncommitted changes on session stop. |
| `git-spice`            | skill + hooks     | Manages stacked Git branches with git-spice (`gs`) CLI. Skill includes full CLI reference, PR status/stack views, tracking external branches, worktrees-and-agents coordination. Hooks: check stack status, reject direct `git push` (forces `gs` workflow).                                                                                                        |
| `review-changes`       | command           | `/review-changes` — detailed code review feedback on quality, security, performance, maintainability.                                                                                                                                                                                                                                                               |
| `task-parallelization` | skill             | Helps the agent parallelize Task tool calls for batch/repetitive operations, optimizing throughput by task complexity.                                                                                                                                                                                                                                              |
| `fix-pr`               | command           | `/fix-pr` — relentlessly iterates review→fix→push cycles until CI passes.                                                                                                                                                                                                                                                                                           |
| `commit-skill`         | skill             | Auto-analyzes git changes and creates well-formatted commits during development.                                                                                                                                                                                                                                                                                    |
| `commit-command`       | command           | `/commit` — AI-generated commit messages matching repo conventions.                                                                                                                                                                                                                                                                                                 |

### Strongly Recommended (most projects)

| Plugin                         | Type            | What It Does                                                                                                                                  |
| ------------------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `product-development-and-sdlc` | skill           | Iterative spec and user story writing. Guides specification through research, review, refinement. Includes spec template reference.           |
| `code-simplifier`              | command + skill | Simplify and refine code for clarity, consistency, maintainability. Requires pr-review-toolkit.                                               |
| `claude-team`                  | skill           | Patterns, pitfalls, and operational knowledge for multi-agent coordination.                                                                   |
| `tmux-subagent`                | command + skill | Launch independent Claude sub-agents in tmux sessions with custom configs, tool restrictions, iTerm integration.                              |
| `context-bloat-prevention`     | hooks           | PostToolUse: detects oversized tool outputs, saves to file instead of context. PreToolUse: redirects commands likely to produce large output. |
| `todo-plus-plus`               | skill + hooks   | Enforces commit-on-complete for tasks. Reminds about ephemeral session awareness.                                                             |
| `memory-manager`               | skill           | Auto-detects and stores user preferences, rules, instructions in CLAUDE.md with scope detection and hierarchical organization.                |
| `correct-behavior`             | command         | `/correct-behavior` — correct AI mistakes and update rules to prevent recurrence.                                                             |

### Situational (project-dependent)

| Plugin                     | Type            | When                                                                |
| -------------------------- | --------------- | ------------------------------------------------------------------- |
| `github-auth-skill`        | skill           | Projects using GitHub API that need device auth flow                |
| `linear-mcp-sync`          | hooks           | Projects using Linear for issue tracking                            |
| `datadog-otel-setup`       | hooks           | Projects with Datadog observability                                 |
| `og-image`                 | skill           | Nuxt/Vue projects needing OpenGraph images                          |
| `data-serialization`       | skill           | YAML/JSON/TOON/XML conversion needs                                 |
| `todo-sync`                | skill + hooks   | Syncs todos between ~/.claude/ and project .claude/                 |
| `sync-settings`            | hooks           | Merge local Claude settings using configurable rules                |
| `remote-config`            | hooks           | Sync upstream Claude config repo on session start                   |
| `word-vomit`               | hooks + skill   | Capture unstructured thoughts → categorize into issues/tasks/docs   |
| `session-report`           | skill           | Generate structured session reports across git history, issues, PRs |
| `statusline`               | hooks           | Configurable status line showing session info, git status           |
| `agent-tab-titles`         | hooks           | Set tmux/iTerm2 tab titles to agent roles                           |
| `self-terminate`           | skill           | Allows graceful self-termination via SIGINT                         |
| `plugin-management`        | skill           | Install, update, manage plugins — hot-reload vs restart knowledge   |
| `skills-maintenance`       | skill           | Maintain, update, improve existing skills                           |
| `command-help-skill`       | skill           | Help agent discover and execute slash commands                      |
| `safety-evaluation-prompt` | hooks           | Pre-tool-call safety evaluation via inline AI                       |
| `safety-evaluation-script` | hooks           | Pre-tool-call safety evaluation via Claude CLI (haiku)              |
| `create-command`           | command + skill | Create and maintain new slash commands                              |

## Marketplace Configuration

Every generated `.claude/settings.json` must include all three marketplaces:

```json
{
  "extraKnownMarketplaces": {
    "nsheaps-ai-mktpl": {
      "source": {
        "source": "github",
        "repo": "nsheaps/ai-mktpl"
      }
    },
    "claude-plugins-official": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-plugins-official"
      }
    },
    "anthropics-claude-code": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-code"
      }
    }
  }
}
```

## Default enabledPlugins

These are the **Always-Include** tier plugins. Every generated prompt must enable them.
The `claude-code-config.md` settings.json template includes these in `enabledPlugins`.
For the **Strongly Recommended** tier, see below — add those for most projects.

```json
{
  "enabledPlugins": {
    "scm-utils@nsheaps-ai-mktpl": true,
    "git-spice@nsheaps-ai-mktpl": true,
    "review-changes@nsheaps-ai-mktpl": true,
    "task-parallelization@nsheaps-ai-mktpl": true,
    "fix-pr@nsheaps-ai-mktpl": true,
    "commit-skill@nsheaps-ai-mktpl": true,
    "commit-command@nsheaps-ai-mktpl": true,
    "ralph-wiggum@anthropics-claude-code": true
  }
}
```

For most projects, also add:

```json
{
  "product-development-and-sdlc@nsheaps-ai-mktpl": true,
  "code-simplifier@nsheaps-ai-mktpl": true,
  "context-bloat-prevention@nsheaps-ai-mktpl": true,
  "todo-plus-plus@nsheaps-ai-mktpl": true,
  "correct-behavior@nsheaps-ai-mktpl": true,
  "memory-manager@nsheaps-ai-mktpl": true
}
```

For agent team / parallel workflows, add:

```json
{
  "claude-team@nsheaps-ai-mktpl": true,
  "tmux-subagent@nsheaps-ai-mktpl": true
}
```

## Session-Start Plugin Installation

```bash
# ---- Plugin Installation ----
echo "[plugins] Installing plugins from marketplaces..."

# Priority 1: nsheaps/ai-mktpl (always first)
claude plugin marketplace add nsheaps/ai-mktpl 2>/dev/null || true

# Always-include plugins
for plugin in scm-utils git-spice review-changes task-parallelization fix-pr \
              commit-skill commit-command; do
  claude plugin install "$plugin@nsheaps-ai-mktpl" 2>/dev/null || true
done

# Recommended plugins (most projects)
for plugin in product-development-and-sdlc code-simplifier context-bloat-prevention \
              todo-plus-plus correct-behavior memory-manager; do
  claude plugin install "$plugin@nsheaps-ai-mktpl" 2>/dev/null || true
done

# Project-specific nsheaps plugins
[ADDITIONAL_NSHEAPS_PLUGINS]

# Priority 2: anthropics/claude-plugins-official
claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
[ADDITIONAL_OFFICIAL_PLUGINS]

# Priority 3: anthropics/claude-code
claude plugin marketplace add anthropics/claude-code 2>/dev/null || true
claude plugin install ralph-wiggum@anthropics-claude-code 2>/dev/null || true
[ADDITIONAL_BUNDLED_PLUGINS]

echo "[plugins] Installation complete"
```

## How nsheaps Plugins Replace Anthropic Fallbacks

| Need               | nsheaps/ai-mktpl (preferred)                                     | anthropic fallback                 |
| ------------------ | ---------------------------------------------------------------- | ---------------------------------- |
| Code review        | `scm-utils` (`/code-review` + review skill + iterate-until-good) | `pr-review-toolkit`, `code-review` |
| Commit messages    | `commit-command` + `commit-skill`                                | `commit-commands`                  |
| Branch management  | `git-spice` (stacked branches, hooks to reject raw git push)     | N/A (no equivalent)                |
| Fix CI             | `fix-pr` (relentless iteration)                                  | N/A                                |
| Simplify code      | `code-simplifier`                                                | N/A                                |
| Task parallelism   | `task-parallelization`                                           | N/A                                |
| Spec writing       | `product-development-and-sdlc` (spec writing with template)      | `feature-dev`                      |
| Quality loop       | `scm-utils`'s iterate-until-good skill                           | `ralph-wiggum`                     |
| Sub-agents         | `tmux-subagent` + `claude-team`                                  | N/A                                |
| Context management | `context-bloat-prevention`                                       | N/A                                |

Note: `ralph-wiggum` from `anthropics/claude-code` is still included because it provides
the self-referential stop-hook pattern that `iterate-until-good` doesn't replicate.
The two are complementary: `iterate-until-good` for per-task review cycles,
`ralph-wiggum` for end-of-phase comprehensive sweeps.

## What NOT to Do

- Do NOT skip nsheaps/ai-mktpl — it has the richest plugin set for the workflows we need
- Do NOT create custom agents for code review, commits, or branch management — these plugins exist
- Do NOT install plugins that aren't relevant just because they exist
- Do NOT hard-code versions unless the user requests it
- The git-spice plugin includes hooks that reject direct `git push` — this is intentional,
  it forces the agent to use `gs branch submit` for proper stacked PR management
