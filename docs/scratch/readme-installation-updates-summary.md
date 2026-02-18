# Plugin README Installation Section Updates - Summary

**Date:** 2026-01-15
**Task:** Standardize Installation sections across all plugin READMEs

## Changes Made

Updated Installation sections in 17 plugin READMEs to reference shared documentation and use consistent format.

### Updated Plugins

All plugins now have standardized Installation sections that:

1. Reference the main [Installation Guide](../../docs/installation.md)
2. Provide Quick Install code block with three methods:
   - Via marketplace (recommended)
   - Via GitHub
   - Locally for testing
3. Include plugin-specific additional requirements where applicable

### Plugin-by-Plugin Summary

| Plugin                       | Previous State              | Updates Made                        | Additional Notes                   |
| ---------------------------- | --------------------------- | ----------------------------------- | ---------------------------------- |
| **commit-command**           | Had detailed steps          | Standardized format                 | -                                  |
| **command-help-skill**       | Had detailed steps          | Standardized format                 | -                                  |
| **correct-behavior**         | Had symlink instructions    | Standardized format                 | -                                  |
| **github-auth-skill**        | Had detailed steps          | Standardized format                 | -                                  |
| **linear-mcp-sync**          | Had complex multi-step      | Standardized + kept MCP setup notes | Preserved Linear MCP server config |
| **memory-manager**           | Had single line             | Standardized format                 | -                                  |
| **safety-evaluation-prompt** | Had minimal instructions    | Standardized format                 | -                                  |
| **safety-evaluation-script** | Had minimal + chmod         | Standardized + kept requirements    | Noted CLI requirement              |
| **task-parallelization**     | Had plugin manager + manual | Standardized format                 | -                                  |
| **sync-settings**            | Had complex hook config     | Standardized + simplified           | Moved complex config to note       |
| **create-command**           | Had single line reference   | Standardized format                 | -                                  |
| **skills-maintenance**       | Had git clone instructions  | Standardized format                 | -                                  |
| **tmux-subagent**            | Had CLI + symlink           | Standardized format                 | -                                  |
| **self-terminate**           | Had GitHub install only     | Standardized format                 | -                                  |
| **commit-skill**             | Had detailed steps          | Standardized format                 | -                                  |
| **data-serialization**       | Had single line             | Standardized format                 | -                                  |
| **og-image**                 | Just had source link        | Added full README + installation    | Created proper structure           |

## Format Template Used

```markdown
## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

\`\`\`bash

# Via marketplace (recommended)

# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub

claude plugins install github:nsheaps/ai-mktpl/plugins/PLUGIN-NAME

# Or locally for testing

cc --plugin-dir /path/to/plugins/PLUGIN-NAME
\`\`\`
```

## Special Cases Handled

### linear-mcp-sync

- Kept MCP server installation instructions
- Simplified hook configuration (noted as automatic)

### safety-evaluation-script

- Added note about Claude CLI requirement
- Noted hook script is automatically made executable

### sync-settings

- Simplified complex hook configuration
- Noted that additional syncconfig.yaml is needed

## Files Modified

Total: 17 READMEs updated

```
plugins/og-image/README.md
plugins/commit-command/README.md
plugins/command-help-skill/README.md
plugins/correct-behavior/README.md
plugins/github-auth-skill/README.md
plugins/linear-mcp-sync/README.md
plugins/memory-manager/README.md
plugins/safety-evaluation-prompt/README.md
plugins/safety-evaluation-script/README.md
plugins/task-parallelization/README.md
plugins/sync-settings/README.md
plugins/create-command/README.md
plugins/skills-maintenance/README.md
plugins/tmux-subagent/README.md
plugins/self-terminate/README.md
plugins/commit-skill/README.md
plugins/data-serialization/README.md
```

## Benefits

1. **Consistency**: All plugins now have identical installation section format
2. **Centralized Documentation**: Single source of truth for installation methods
3. **Easier Maintenance**: Update installation docs in one place
4. **Better UX**: Users know what to expect across all plugins
5. **Reduced Duplication**: Less repeated content across READMEs

## Next Steps

1. Validate all updated READMEs render correctly
2. Ensure docs/installation.md exists and is comprehensive
3. Test installation instructions for accuracy
4. Consider creating docs/manual-installation.md if it doesn't exist
