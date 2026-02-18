# plugin-management

Skill for installing, updating, and managing Claude Code plugins.

## What It Provides

A single skill (`plugin-management`) that covers:

- **Installation methods** — marketplace, `--plugin-dir`, team config
- **Updating plugins** — automatic checks, manual reinstall
- **Hot-reload behavior** — what requires a restart vs what takes effect immediately
- **Verification** — how to check if a plugin loaded correctly
- **Troubleshooting** — common failures and their fixes
- **Known issues** — upstream bugs with workarounds

## Installation

```
/plugin install plugin-management@nsheaps/ai-mktpl
```

## Sources

Research based on:

- Claude Code v2.1.39–2.1.45 binary analysis
- Official Claude Code plugin documentation
- GitHub issue tracking for known bugs
