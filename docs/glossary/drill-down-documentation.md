# Drill-Down Documentation

**Definition:** A documentation pattern where high-level overviews link to progressively more detailed documents, allowing readers to "drill down" to the specificity they need.

**Structure:**

```
README.md                    # High-level overview, quick start
├── docs/usage.md            # Detailed usage patterns
├── docs/configuration.md    # All configuration options
└── docs/troubleshooting.md  # Common issues and solutions
```

**Benefits:**

- Keeps top-level docs concise and scannable
- Allows deep-dive without cluttering main documentation
- Supports different reader needs (quick reference vs. comprehensive)

**Example in this repo:** The `code-simplifier` plugin uses drill-down docs:

- `README.md` - Quick installation and usage
- `commands/simplify.md` - Command implementation with dependency flow
- `skills/code-simplifier/SKILL.md` - Full troubleshooting and CLI reference
