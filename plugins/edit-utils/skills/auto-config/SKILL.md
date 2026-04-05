---
description: "Auto-detect project formatting tools and configure edit-utils settings"
---

# Auto-Configure Edit Utils

Detect the project's formatting and linting tools and write a `plugins.settings.yaml` override.

## Steps

1. **Explore the project** for formatting configuration:
   - `.prettierrc`, `.prettierrc.json`, `.prettierrc.yaml`, `prettier.config.*`
   - `biome.json`, `biome.jsonc`
   - `.editorconfig`
   - `pyproject.toml` (black, ruff)
   - `mise.toml` (npm tools like prettier, eslint)
   - `package.json` (scripts, devDependencies)

2. **Determine the formatter command:**
   - If prettier config found → `formatter: "prettier --write"`
   - If biome config found → `formatter: "biome format --write"`
   - If black/ruff in pyproject.toml → `formatter: "black"` or `formatter: "ruff format"`
   - If multiple found, prefer the one with a config file

3. **Determine file extensions** from the project's source files and formatter config.

4. **Write the config** to `$CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml`:

```yaml
edit-utils:
  enabled: true
  formatter: "prettier --write"
  extensions:
    - .json
    - .yaml
    - .yml
    - .md
    - .ts
    - .tsx
```

5. **Verify** the formatter is available (`command -v`) and test it on a sample file.

## Auto-Config Pattern

This skill implements the **auto-config pattern**: instead of hardcoding tool assumptions, the plugin discovers what tools the project uses and configures itself accordingly. This makes the plugin work across diverse projects without manual setup.

For session-start automation, a SessionStart hook can invoke this skill using a fast model (haiku) to explore the project and populate the config on first use.
