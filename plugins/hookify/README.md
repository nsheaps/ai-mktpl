# hookify

Watch for dependency file changes and remind about related updates (e.g., license disclosures).

## How it works

When you edit or write a dependency file (like `package.json`, `requirements.txt`, `Cargo.toml`, etc.), hookify outputs an advisory message reminding the agent to check if related files need updating.

This is useful for keeping license disclosures, lock files, or other derived artifacts in sync with dependency changes.

## Configuration

Add to your project's `.claude/plugins.settings.yaml`:

```yaml
hookify:
  enabled: true
  watchFiles:
    - "package.json"
  reminderMessage: "Dependencies changed. Check if the LICENSES array in SettingsModal.tsx needs updating."
  checkFiles:
    - "packages/ui/src/components/settings/SettingsModal.tsx"
```

### Settings

| Key               | Type   | Default | Description                                      |
| ----------------- | ------ | ------- | ------------------------------------------------ |
| `enabled`         | bool   | `true`  | Enable/disable the plugin                        |
| `watchFiles`      | list   | `[]`    | File basenames to watch (supports glob patterns) |
| `reminderMessage` | string | generic | Message shown when a watched file changes        |
| `checkFiles`      | list   | `[]`    | Files the agent should review                    |

## Installation

Enable in your project or user settings:

```json
{
  "enabledPlugins": ["hookify"]
}
```
