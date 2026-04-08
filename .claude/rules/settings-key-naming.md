# Settings Key Naming Convention

## Rule: Use camelCase for Plugin Settings Keys

All plugin settings keys in `*.settings.yaml` files and `plugins.settings.yaml` overrides MUST use **camelCase**.

This applies to:

- Plugin default settings files (`<plugin-name>.settings.yaml`)
- Project-level overrides (`$CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml`)
- User-level overrides (`~/.claude/plugins.settings.yaml`)
- String arguments to `plugin_get_config` and `plugin_get_config_array` in hook scripts
- Documentation (READMEs, rules) that reference settings keys

## Why camelCase

- Consistent with Claude Code's own `settings.json` keys (`enabledPlugins`, `allowedTools`)
- Consistent with `plugin.json` manifest fields (npm/JSON conventions)
- Matches the broader JS/TS ecosystem convention for configuration keys

## Examples

```yaml
# Good
my-plugin:
  autoInstall: true
  installToProject: true
  backgroundInstall: false
  syncSettingsTarget: "local"

# Bad
my-plugin:
  auto_install: true
  install_to_project: true
  background_install: false
  sync_settings_target: "local"
```

## Single-Word Keys

Single-word keys like `enabled`, `version`, `target`, `strategy`, `sources` are unaffected — they have no casing distinction.

## In Hook Scripts

The string passed to `plugin_get_config` must match the YAML key exactly:

```bash
# Good
auto_install="$(plugin_get_config "autoInstall" "true")"

# Bad
auto_install="$(plugin_get_config "auto_install" "true")"
```

Note: Bash variable names (left side of assignment) remain snake_case per bash convention. Only the config key string (the YAML key being looked up) uses camelCase.
