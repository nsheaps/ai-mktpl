# Plugin Settings Framework

A minimal framework for plugins to load configuration and write environment variables to Claude Code settings files.

## Settings File

`.claude/plugins.settings.json`

```json
{
  "plugin-name": {
    "target": "local",
    "env": {
      "VAR_NAME_1": "value1",
      "VAR_NAME_2": "value2"
    }
  }
}
```

## Settings

| Setting  | Description                              | Default   |
| -------- | ---------------------------------------- | --------- |
| `target` | Where to write env vars                  | `"local"` |
| `env`    | Key-value pairs of environment variables | `{}`      |

### Target Options

| Target    | File                          | Use Case                     |
| --------- | ----------------------------- | ---------------------------- |
| `local`   | `.claude/settings.local.json` | Personal config (gitignored) |
| `project` | `.claude/settings.json`       | Shared team config           |
| `user`    | `~/.claude/settings.json`     | Global user config           |

## Using the Settings Library

```bash
# Source the library
source "$CLAUDE_PROJECT_DIR/.claude/lib/load-plugin-settings.sh"

# Load settings for your plugin
SETTINGS=$(load_plugin_settings "my-plugin")

# Get target and env vars
TARGET=$(get_target "$SETTINGS")
ENV_VARS=$(get_env "$SETTINGS")

# Resolve target to file path
SETTINGS_FILE=$(resolve_target_file "$TARGET" "$PROJECT_DIR")
```

## Example Plugin Implementation

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Source settings library
source "$PROJECT_DIR/.claude/lib/load-plugin-settings.sh"

# Load this plugin's settings
SETTINGS=$(load_plugin_settings "my-plugin")
TARGET=$(get_target "$SETTINGS")
ENV_VARS=$(get_env "$SETTINGS")

# Skip if no env vars configured
if [[ "$ENV_VARS" == "{}" ]]; then
  exit 0
fi

# Resolve target file
SETTINGS_FILE=$(resolve_target_file "$TARGET" "$PROJECT_DIR")

# Ensure directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Read or create existing settings
if [[ -f "$SETTINGS_FILE" ]]; then
  EXISTING=$(cat "$SETTINGS_FILE")
else
  EXISTING="{}"
fi

# Merge env vars into settings
UPDATED=$(echo "$EXISTING" | jq --argjson env "$ENV_VARS" '.env = ((.env // {}) * $env)')

# Write back
echo "$UPDATED" | jq '.' > "$SETTINGS_FILE"

echo "Configured environment in $(basename "$SETTINGS_FILE")"
```

## Dependencies

- `jq` - JSON processing (included in mise.toml)
