Get rid of python here

###### BELOW BE VIBES

# Sync Settings Plugin

Automatically sync and merge local Claude Code settings, commands, and files using configurable rules. Perfect for maintaining local customizations that shouldn't be committed to version control, or for syncing shared configurations across projects.

## Overview

The Sync Settings Plugin uses Claude Code hooks to automatically synchronize files and settings at session start. It reads rules from `.claude/syncconfig.yaml` and processes them in order, supporting:

- **JSON Merging**: Merge local settings into project settings (e.g., `settings.local.json` -> `settings.json`)
- **File Syncing**: Copy or symlink files from one location to another
- **Directory Syncing**: Sync entire directories with glob patterns
- **Content Replacement**: Set file contents directly from configuration

## Features

- JSON deep-merge with selective key filtering
- Glob pattern support for file matching
- Multiple sync modes: copy, symlink, merge, hoist
- Protection against accidental overwrites
- Works with `.gitignore` to keep local changes out of version control

## Installation

### Via Claude Code Plugin Manager

1. Open Claude Code
2. Run `/plugin marketplace add nsheaps/.ai`
3. Find "Sync Settings" plugin
4. Click "Install now"
5. Restart Claude Code

### Manual Installation

1. Copy the plugin to your Claude Code plugins directory:

```bash
cp -r /path/to/marketplace/plugins/sync-settings ~/.claude/plugins/
```

2. Add the hook to your settings (user or project level):

**Option A: Add to `~/.claude/settings.json`** (applies to all projects):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/plugins/sync-settings/hooks/sync-settings.py"
          }
        ]
      }
    ]
  }
}
```

**Option B: Add to `.claude/settings.json`** (project-specific):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .claude/hooks/sync-settings.py"
          }
        ]
      }
    ]
  }
}
```

3. Create your `syncconfig.yaml` (see Configuration below)

## Configuration

Create a `.claude/syncconfig.yaml` file in your project root. Rules are processed in order from top to bottom.

### Basic Structure

```yaml
# Each item is a sync rule processed in order
- source: ./settings.local.json
  target: ./settings.json
  mode: merge

- source: ../shared/commands/*.md
  target: ./commands/
  mode: sync
```

### Sync Modes

#### `merge` - JSON Deep Merge

Merges source JSON file into target JSON file. Perfect for maintaining local settings that extend project defaults.

```yaml
- source: ./settings.local.json
  target: ./settings.json
  mode: merge
```

**With Key Filtering** - Only merge specific keys:

```yaml
- source: ./settings.local.json
  target: ./settings.json
  mode: merge
  only:
    - key: permissions
      only: allow # Only merge the 'allow' subkey
    - key: enabledMcpServers # Merge entire key
```

#### `sync` - File/Directory Sync

Copies or symlinks files from source to target. Supports glob patterns.

```yaml
# Copy a single file
- source: ../CLAUDE.md
  target: ../AGENTS.md
  mode: sync
  sync-mode: copy # 'copy' (default) or 'symlink'
  if-present: do-nothing # 'do-nothing' (default), 'replace', or 'error-if-different'

# Sync multiple files with glob
- source: ../.ai/commands/*.md
  target: ./commands/
  mode: sync
  sync-mode: symlink
```

**Options:**

- `sync-mode`: `copy` (default) or `symlink`
- `if-present`:
  - `do-nothing` (default) - Skip if target exists
  - `replace` - Overwrite existing files
  - `error-if-different` - Fail if target exists and differs

#### `source-only` - Strict Source Sync

Ensures target directory **only** contains files from the source. Files in target that aren't in source are removed.

```yaml
- source: ../shared/commands/*.md
  target: ./commands/
  mode: source-only
  sync-mode: symlink
```

#### `hoist` - Move and Link

Moves files from target to source directory, then creates links back. Useful for centralizing files that are scattered across projects.

```yaml
- source: ../.ai/hoisted-commands/
  target: ./commands/
  mode: hoist
  sync-mode: symlink
```

#### `replace` - Set Contents Directly

Sets file contents directly from the configuration.

```yaml
- source: ../CLAUDE.md
  mode: replace
  contents: |
    @AGENTS.md
```

## Complete Example

```yaml
# .claude/syncconfig.yaml

# 1. Merge local permissions into project settings
#    Keeps your personal permissions without committing them
- source: ./settings.local.json
  target: ./settings.json
  mode: merge
  only:
    - key: permissions
      only: allow
    - key: enabledMcpServers

# 2. Sync shared commands from central location
#    All .md files from .ai/commands will be linked to .claude/commands
- source: ../.ai/commands/*.md
  target: ./commands/
  mode: sync
  sync-mode: symlink
  if-present: replace

# 3. Create AGENTS.md as a copy of CLAUDE.md
#    For compatibility with different AI assistants
- source: ../CLAUDE.md
  target: ../AGENTS.md
  mode: sync
  sync-mode: copy
  if-present: do-nothing

# 4. Set CLAUDE.md to reference AGENTS.md
#    Keeps one source of truth
- source: ../CLAUDE.md
  mode: replace
  contents: |
    @AGENTS.md
```

## Path Resolution

Paths are resolved relative to the `.claude/` directory:

- `./` - Relative to `.claude/` directory
- `../` - Relative to project root
- Absolute paths are supported but not recommended

**Examples:**

```yaml
# These are equivalent when syncconfig.yaml is in .claude/
source: ./settings.local.json  # .claude/settings.local.json
source: settings.local.json    # project-root/settings.local.json

# Reference project root
source: ../CLAUDE.md           # project-root/CLAUDE.md
target: ../AGENTS.md           # project-root/AGENTS.md
```

## Integration with .gitignore

Add local settings files to `.gitignore` to prevent accidental commits:

```gitignore
# .gitignore
.claude/settings.local.json
.claude/syncconfig.yaml
```

Or commit `syncconfig.yaml` as a team standard but ignore local settings:

```gitignore
# .gitignore
.claude/settings.local.json
.claude/local/
```

## Requirements

- **Python 3.6+**: Required for the hook script
- **PyYAML**: Install with `pip install pyyaml`
- **Claude Code**: Latest version with hooks support

## Environment Variables

The hook uses these Claude Code environment variables:

- `CLAUDE_PROJECT_DIR`: Project root directory (automatically set by Claude Code)

## Troubleshooting

### Hook Not Running

1. Verify the hook is configured in `settings.json`
2. Check that Python 3 is available: `python3 --version`
3. Ensure PyYAML is installed: `pip install pyyaml`
4. Check hook path is correct (absolute or relative to project)

### Files Not Syncing

1. Verify `syncconfig.yaml` exists in `.claude/`
2. Check YAML syntax is valid
3. Ensure source files exist
4. Check file permissions

### JSON Merge Not Working

1. Verify both source and target are valid JSON
2. Check `only` key names match exactly
3. Ensure paths are correct

### Permission Errors

1. Check file/directory permissions
2. For symlinks, ensure target directory exists
3. On Windows, symlinks may require administrator privileges

## Security Considerations

- The hook executes at session start before any tools run
- Validate your `syncconfig.yaml` before use
- Be cautious with `replace` mode - it overwrites files without confirmation
- Use `if-present: error-if-different` for safety-critical files

## Related Plugins

- **[Commit Command](../commit-command)**: AI-assisted git commits
- **[Smart Commit Skill](../commit-skill)**: Automatic intelligent commits

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Documentation**: [Main README](../../README.md)
- **Claude Code Docs**: [https://docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code)

## Changelog

### Version 1.0.0

- Initial release
- JSON deep-merge with key filtering
- File/directory sync with glob patterns
- Symlink and copy modes
- source-only and hoist modes
- Content replacement mode

---

**Made with Claude Code** | Part of the [Claude Code Plugin Marketplace](../../README.md)
