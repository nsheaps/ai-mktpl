# Plugin Wrapper Pattern

**Definition:** A plugin that provides a simplified interface to an existing agent or tool, handling dependency management, configuration, and user guidance.

**Structure:**

```
wrapper-plugin/
├── .claude-plugin/plugin.json  # Declares wrapper, not new agent
├── commands/command.md         # User-facing command
├── skills/*/SKILL.md           # Usage documentation
└── README.md                   # Installation guide
```

**Benefits:**

- Improves discoverability of existing capabilities
- Centralizes dependency management logic
- Provides consistent UX across different underlying agents
- Reduces duplication of agent code

**Example:** The `code-simplifier` plugin wraps `pr-review-toolkit:code-simplifier`.
