# Incident Tracker Plugin

A Claude Code plugin for tracking behavioral incidents, documenting corrections, and maintaining learned rules with footnote references.

## Features

- **Structured incident documentation** with YAML front matter
- **Automatic rule derivation** from incidents
- **Footnote references** linking rules to source incidents
- **Severity classification** (low, medium, high)
- **Tag-based organization** for searching

## Installation

Add to your Claude Code config:

```json
{
  "plugins": {
    "entries": {
      "incident-tracker": {
        "enabled": true,
        "config": {
          "incidentsDir": "incidents/behavioral",
          "rulesFile": "AGENTS.md",
          "rulesSection": "Learned Behaviors"
        }
      }
    }
  }
}
```

## Usage

When you receive a behavioral correction:

```
/incident <description>
```

The plugin will:
1. Stop the current task
2. Document the incident
3. Derive a reusable rule
4. Update the rules file
5. Confirm with you before continuing

## File Structure

```
workspace/
├── AGENTS.md                    # Rules file with Learned Behaviors section
└── incidents/
    └── behavioral/
        ├── 2026-03-20--installed-without-asking.md
        ├── 2026-03-21--clawhub-rabbit-hole.md
        └── ...
```

## Incident Format

Each incident file has:

- **YAML front matter** with date, severity, tags
- **Structured sections** for context
- **Derived rules** that feed back into AGENTS.md

## Rules Format

Rules in AGENTS.md use this pattern:

```markdown
N. **Rule title** — Rule description. [^rule-N]

[^rule-N]: [YYYY-MM-DD -- Incident Title](incidents/behavioral/YYYY-MM-DD--incident.md)
```

## Best Practices

1. **Stop immediately** when corrected - don't continue the previous task
2. **Be specific** in rule derivation - vague rules don't help
3. **Include quotes** when possible - user's exact words matter
4. **Link related incidents** - patterns emerge over time
5. **Confirm before continuing** - user should verify the characterization

## License

MIT
