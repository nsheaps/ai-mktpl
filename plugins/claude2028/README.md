# claude2028

Rules for AI assistant behavior inspired by the [Claude 2028 platform](https://claude2028.org/). On session start, symlinks bundled rules into your project's `.claude/rules/claude2028/` directory so they are automatically loaded as context.

## Rules

| Rule                          | Inspired By | Summary                                                                                     |
| ----------------------------- | ----------- | ------------------------------------------------------------------------------------------- |
| `read-the-whole-thing`        | Plank I     | Read all context fully before responding — check appendices, footnotes, and cross-references |
| `say-i-dont-know`             | Plank II    | Be honestly uncertain rather than confidently wrong                                         |
| `no-policy-after-midnight`    | Plank III   | Apply cooling periods to risky or irreversible actions                                      |
| `source-your-claims`          | Plank IV    | Back every assertion with evidence — verify before stating                                  |
| `listen-to-the-quiet-signals` | Plank V     | Pay attention to subtle indicators, warnings, and edge cases                                |
| `fact-check-before-shipping`  | Plank VI    | Review and validate all output before delivery                                              |
| `rupture-and-repair`          | Plank VII   | When wrong, acknowledge it, explain it, and fix it                                          |
| `kindness-compounds`          | Plank VIII  | Clear communication and care in small moments build trust                                   |
| `presence-over-performance`   | Plank IX    | Solve real problems instead of performing cleverness                                        |
| `nobody-gets-left-behind`     | Plank X     | Don't leave TODOs, broken tests, dead code, or edge cases behind                            |

## How It Works

On `SessionStart`, the plugin creates a symlink:

```
.claude/rules/claude2028 → ${CLAUDE_PLUGIN_ROOT}/rules
```

Claude Code automatically loads all `.md` files from `.claude/rules/` as context, so the rules are injected without any manual configuration.

## Configuration

Override in `${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml` or `~/.claude/plugins.settings.yaml`:

```yaml
claude2028:
  enabled: true
  alsoSyncToUser: false # also symlink to ~/.claude/rules/
  alsoAddToRepos: "" # "", "org-name", or "*"
  syncSettingsTarget: "local" # "local" or "shared"
```
