---
description: Auto-detect dependency files in the project and configure hookify watch rules
triggers:
  - "configure hookify"
  - "set up hookify"
  - "auto-config hookify"
  - "hookify auto-config"
---

# hookify Auto-Config

Detect dependency management files in the current project and configure hookify to watch them.

## What this skill does

1. Scans the project root for common dependency files:
   - `package.json` (Node.js/Bun)
   - `requirements.txt` / `pyproject.toml` (Python)
   - `Cargo.toml` (Rust)
   - `go.mod` (Go)
   - `Gemfile` (Ruby)
   - `build.gradle` / `pom.xml` (Java)
2. Searches for any existing license disclosure files or components
3. Writes the appropriate hookify config to `.claude/plugins.settings.yaml`

## Steps

1. Search for dependency files at the project root:
   ```bash
   ls package.json requirements.txt pyproject.toml Cargo.toml go.mod Gemfile build.gradle pom.xml 2>/dev/null
   ```

2. Search for license-related files or components:
   ```bash
   grep -rl "LICENSES\|LicensesDisclosure\|license.*disclosure\|third.party.licenses" --include="*.tsx" --include="*.ts" --include="*.jsx" --include="*.js" --include="*.md" . 2>/dev/null | head -10
   ```

3. Write the config to `.claude/plugins.settings.yaml` under the `hookify` key, merging with any existing config. Include:
   - `watchFiles`: the dependency files found
   - `reminderMessage`: a project-specific reminder mentioning the license file/component found
   - `checkFiles`: paths to any license disclosure files found

4. Ensure `hookify` is in the project's `enabledPlugins` in `.claude/settings.json` or `.claude/settings.local.json`
