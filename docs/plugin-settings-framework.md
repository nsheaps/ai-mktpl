# Plugin Settings Framework

A reusable pattern for plugins to load configuration from central or plugin-specific settings files.

## Settings Resolution Order

Settings are loaded from the first available source:

1. **Plugin-specific file:** `plugins/<plugin-name>/<plugin-name>.settings.yaml`
2. **Plugin-specific file:** `plugins/<plugin-name>/<plugin-name>.settings.json`
3. **Central file section:** `.claude/plugins.settings.yaml` → `<plugin-name>:` key
4. **Central file section:** `.claude/plugins.settings.json` → `<plugin-name>` key
5. **Plugin defaults:** Hardcoded in the plugin

## File Locations

### Central Settings File

`.claude/plugins.settings.yaml` (or `.json`)

```yaml
# Each top-level key is a plugin name
plugin-name:
  setting1: value1
  setting2: value2

another-plugin:
  enabled: true
  option: value
```

### Plugin-Specific Settings File

`plugins/<plugin-name>/<plugin-name>.settings.yaml`

Used when you need to override central settings for a specific plugin.

## Using the Settings Library

```bash
# Source the library
source "$CLAUDE_PROJECT_DIR/.claude/lib/load-plugin-settings.sh"

# Load settings with defaults
SETTINGS=$(load_plugin_settings "my-plugin" '{"default": "value"}')

# Get specific settings
VALUE=$(get_setting "$SETTINGS" ".key" "default-value")
NESTED=$(get_setting "$SETTINGS" ".nested.key" "default")

# Resolve environment variables
API_KEY=$(resolve_env_var "$(get_setting "$SETTINGS" ".api_key" "")")
```

## Target Settings File Resolution

Plugins that write to Claude Code's settings files can use the `resolve_target_settings_file` function:

```bash
# Resolve target name to file path
TARGET=$(get_setting "$SETTINGS" ".target" "local")
SETTINGS_FILE=$(resolve_target_settings_file "$TARGET" "$PROJECT_DIR")
```

Supported target values:

| Target    | File                          | Use Case                     |
| --------- | ----------------------------- | ---------------------------- |
| `local`   | `.claude/settings.local.json` | Personal config (gitignored) |
| `project` | `.claude/settings.json`       | Shared team config           |
| `user`    | `~/.claude/settings.json`     | Global user config           |

## Environment Variable References

Settings can reference environment variables using `${VAR_NAME}` or `${VAR_NAME:-default}` syntax:

```yaml
my-plugin:
  api_key: ${MY_API_KEY}
  endpoint: ${MY_ENDPOINT:-https://default.example.com}
```

The `resolve_env_var` function uses `envsubst` to expand these at runtime, supporting the full range of shell variable expansion syntax.

## 1Password References

For secrets management with 1Password CLI:

```yaml
my-plugin:
  api_key: op://vault/item/field
```

Plugins should check for `op://` prefix and use `op read` to fetch values.

## Best Practices

### DO

- Use `target: local` for configuration that creates files (keeps them gitignored)
- Reference secrets via environment variables: `${SECRET_NAME}`
- Provide sensible defaults in your plugin
- Document all settings in your plugin's README
- Create a test script to verify configuration doesn't cause git changes

### DON'T

- Commit literal API keys to `plugins.settings.yaml`
- Use `target: project` with literal secrets in shared repos
- Skip defaults - always provide fallback values
- Assume yq is installed - check and provide helpful error

## Example Plugin Implementation

```bash
#!/usr/bin/env bash
set -euo pipefail

# Load settings library
if [[ -f "$CLAUDE_PROJECT_DIR/.claude/lib/load-plugin-settings.sh" ]]; then
  source "$CLAUDE_PROJECT_DIR/.claude/lib/load-plugin-settings.sh"
else
  echo "ERROR: Settings library not found" >&2
  exit 1
fi

# Default settings
DEFAULTS='{
  "enabled": true,
  "option": "default-value"
}'

# Load and use settings
SETTINGS=$(load_plugin_settings "my-plugin" "$DEFAULTS")
ENABLED=$(get_setting "$SETTINGS" ".enabled" "true")
OPTION=$(get_setting "$SETTINGS" ".option" "default-value")

if [[ "$ENABLED" != "true" ]]; then
  exit 0
fi

# Plugin logic here...
```

## Testing Plugin Configuration

Every plugin that modifies files should include a test script:

```bash
#!/usr/bin/env bash
# scripts/test-configuration.sh

# 1. Check initial git state
# 2. Run the plugin's hooks
# 3. Verify no uncommitted changes to tracked files
# 4. Exit non-zero if changes detected
```

Run tests via justfile:

```bash
just test-plugin-config my-plugin
```

## Dependencies

The settings library requires:

- `jq` - JSON processing (included in mise.toml)
- `yq` - YAML processing (optional, for YAML files)

If `yq` is not available and YAML files are used, the library will return defaults.
