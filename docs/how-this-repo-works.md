# How This Repo Works

This is the **ai-mktpl** plugin marketplace — a central repository for Claude Code plugins, shared libraries, organization-wide rules, and reusable skills.

## Repository Structure

```
ai-mktpl/
├── .ai/rules/               # Organization-wide rules (synced to ~/.claude/rules/)
├── .claude-plugin/
│   └── marketplace.json     # Plugin registry — every plugin must have an entry here
├── .github/                  # CI workflows, labeling, review automation
├── docs/                     # Documentation, specs, research
│   ├── specs/                # Feature specifications (draft → reviewed → live)
│   └── research/             # Research findings
├── plugins/                  # All plugins live here (one directory per plugin)
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json   # Plugin manifest (name, version, auto_discovery, etc.)
│       ├── hooks/            # Hook configurations and scripts
│       │   ├── hooks.json    # Hook event bindings
│       │   └── scripts/      # Hook implementation scripts
│       ├── skills/           # Plugin skills (.md files)
│       ├── agents/           # Plugin agent definitions (.md files)
│       ├── commands/         # Slash commands (.md files)
│       ├── rules/            # Plugin-scoped rules (.md files)
│       ├── lib/              # Shared library symlinks (→ ../../shared/lib/)
│       └── README.md         # Plugin documentation
├── shared/
│   ├── lib/                  # Shared bash libraries used across plugins
│   │   ├── hook-logging.sh   # Standardized hook output framework
│   │   ├── log.sh            # Logging utilities
│   │   ├── plugin-config-read.sh  # Plugin settings reader
│   │   ├── safe-settings-write.sh # Safe settings.json modification
│   │   └── tool-install.sh   # Tool installation helpers
│   └── skills/               # Shared skills (symlinked by multiple plugins)
└── prompts/                  # Shared prompt templates
```

## Key Concepts

### Plugin Manifest (`plugin.json`)

Every plugin has a `.claude-plugin/plugin.json` manifest:

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "What this plugin does",
  "author": { "name": "...", "email": "...", "url": "..." },
  "keywords": ["..."],
  "auto_discovery": {
    "skills": "skills/",
    "agents": "agents/",
    "commands": "commands/"
  }
}
```

### Marketplace Registry

`.claude-plugin/marketplace.json` is the central registry. Every plugin **must** have an entry here to be installable. Entries are alphabetically sorted.

### Shared Libraries

Plugins share common code via symlinks to `shared/lib/`. The `hook-logging.sh` framework is critical — it enforces exit 0 for all hooks and standardizes output formatting. All new hooks should use this framework.

### Hook Conventions

- **Informational hooks** (SessionStart, PostToolUse): Always exit 0, surface messages via stdout/systemMessage
- **Blocking hooks** (PreToolUse): Use exit 2 to block, or JSON `permissionDecision: deny`
- **Framework**: Use `shared/lib/hook-logging.sh` for standardized behavior

### CD Auto-Bump

When PRs merge, a CD workflow auto-bumps plugin versions and updates `marketplace.json`. This can cause PR branches to show marketplace.json changes that don't belong to them — this is a known issue (nsheaps/ai-mktpl#351).

## Where Things Live

| Artifact Type     | Location                                    | Notes                           |
| ----------------- | ------------------------------------------- | ------------------------------- |
| Plugin source     | `plugins/<name>/`                           | One directory per plugin        |
| Plugin manifest   | `plugins/<name>/.claude-plugin/plugin.json` | Required for every plugin       |
| Hook scripts      | `plugins/<name>/hooks/scripts/`             | Executed by hooks.json bindings |
| Skills            | `plugins/<name>/skills/`                    | Auto-discovered if configured   |
| Agent definitions | `plugins/<name>/agents/`                    | Auto-discovered if configured   |
| Commands          | `plugins/<name>/commands/`                  | Auto-discovered if configured   |
| Rules             | `plugins/<name>/rules/`                     | Loaded as project rules         |
| Shared libraries  | `shared/lib/`                               | Symlinked by plugins via `lib/` |
| Shared skills     | `shared/skills/`                            | Symlinked by multiple plugins   |
| Org-wide rules    | `.ai/rules/`                                | Synced to `~/.claude/rules/`    |
| Marketplace       | `.claude-plugin/marketplace.json`           | Central plugin registry         |
| Specs             | `docs/specs/{draft,reviewed,live}/`         | Feature specifications          |
| Research          | `docs/research/`                            | Investigation reports           |

## Working In This Repo

### Creating a New Plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json`
2. Add hooks, skills, agents, commands as needed
3. Symlink shared libs: `ln -s ../../../shared/lib/hook-logging.sh lib/`
4. Add entry to `.claude-plugin/marketplace.json` (alphabetical order)
5. Follow existing plugins as reference (e.g., `common-sense`, `scm-utils`, `github-app`)

### Modifying an Existing Plugin

1. Check the plugin's current structure and patterns
2. Use `shared/lib/hook-logging.sh` for any new hooks
3. Bump the version in `plugin.json` if changing behavior
4. Test hooks locally before pushing

### Prefer Plugins Over Project-Specific Config

Per the `using-skills-and-plugins` rule in `common-sense`: always prefer encapsulating behavior in a reusable plugin rather than project-specific configuration. Plugins are shareable, versioned, and discoverable.
