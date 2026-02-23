# datadog-otel-setup

Claude Code plugin that configures native OpenTelemetry (OTEL) export to Datadog.

## How It Works

On **SessionStart**, the plugin:

1. Reads configuration from YAML config files (project → user → plugin defaults)
2. Resolves the Datadog API key (env var, 1Password ref, or literal)
3. Writes OTEL environment variables to `~/.claude/settings.local.json`

Claude Code's native OTEL integration then picks up these env vars and exports telemetry data to Datadog.

## Configuration

Configuration is resolved in order (first match wins):

1. **Project-level**: `${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml`
2. **User-level**: `~/.claude/plugins.settings.yaml`
3. **Plugin defaults**: `datadog-otel-setup.settings.yaml` (bundled with plugin)

### Config Format

```yaml
datadog-otel-setup:
  enabled: true
  endpoint: "https://otel.datadoghq.com:4317"
  metrics_exporter: "otlp"
  logs_exporter: "otlp"
  api_key: "${DD_API_KEY}"
```

### API Key Resolution

The `api_key` field supports three formats:

| Format | Example | How It Works |
|--------|---------|--------------|
| Env var reference | `${DD_API_KEY}` | Expanded from shell environment |
| 1Password ref | `op://Engineering/dd-key/credential` | Resolved via `op read` |
| Literal | `abc123...` | Used as-is (only for gitignored configs) |

**Recommended**: Use `${DD_API_KEY}` and set the env var in your shell profile.

### Disabling

Set `enabled: false` in any config file to disable OTEL without uninstalling.

## Environment Variables Written

| Variable | Value |
|----------|-------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` |
| `OTEL_METRICS_EXPORTER` | `otlp` (configurable) |
| `OTEL_LOGS_EXPORTER` | `otlp` (configurable) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://otel.datadoghq.com:4317` (configurable) |
| `OTEL_EXPORTER_OTLP_HEADERS` | `DD-API-KEY=<resolved_key>` |

## Dependencies

- `jq` — for JSON processing
- `yq` — Go version ([mikefarah/yq](https://github.com/mikefarah/yq)) for YAML config parsing
- `op` — 1Password CLI (optional, only needed for `op://` references)

## Security

- API keys are never committed to the plugin source
- The plugin writes to `settings.local.json` which should be gitignored
- Prefer env var or 1Password references over literal keys
