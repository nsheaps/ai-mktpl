# datadog-otel-setup

Configure Claude Code's native OpenTelemetry integration for Datadog observability.

## Overview

This plugin automatically configures Claude Code's OTEL settings at session start, enabling metrics and logs to be sent to Datadog. It uses the plugin settings framework to manage configuration.

## Quick Start

1. **Set your Datadog API key:**

   ```bash
   export DD_API_KEY="your-datadog-api-key"
   ```

2. **Start a Claude Code session** - the plugin automatically configures OTEL settings.

3. **Verify in Datadog** - Look for `claude-code` service in APM or logs.

## Configuration

Settings are loaded from (in priority order):

1. `plugins/datadog-otel-setup/datadog-otel-setup.settings.yaml`
2. `.claude/plugins.settings.yaml` → `datadog-otel-setup:` section

### Default Settings

```yaml
datadog-otel-setup:
  # Target settings file (local recommended for gitignored config)
  target: local # local | project | user

  # OTEL Configuration
  enabled: true
  endpoint: "https://otel.datadoghq.com:4317"
  protocol: grpc # grpc | http/json | http/protobuf

  # API key (env var reference recommended)
  api_key: ${DD_API_KEY}

  # Resource attributes for OTEL
  resource_attributes:
    service.name: claude-code
    deployment.environment: development
```

### Target Options

| Target    | File                          | Use Case                     |
| --------- | ----------------------------- | ---------------------------- |
| `local`   | `.claude/settings.local.json` | Personal config (gitignored) |
| `project` | `.claude/settings.json`       | Shared team config           |
| `user`    | `~/.claude/settings.json`     | Global user config           |

**Recommendation:** Use `target: local` to avoid committing API keys or personal settings.

### API Key Options

```yaml
# Environment variable (recommended)
api_key: ${DD_API_KEY}

# 1Password (requires op CLI)
api_key: op://Private/Datadog/api-key

# Direct value (NOT recommended for shared repos)
api_key: your-literal-api-key
```

## Environment Variables

The plugin sets these OTEL environment variables in your settings.json:

| Variable                       | Description                      |
| ------------------------------ | -------------------------------- |
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enables Claude Code telemetry    |
| `OTEL_METRICS_EXPORTER`        | Set to `otlp` for metrics export |
| `OTEL_LOGS_EXPORTER`           | Set to `otlp` for logs export    |
| `OTEL_EXPORTER_OTLP_PROTOCOL`  | Protocol (grpc, http/json, etc.) |
| `OTEL_EXPORTER_OTLP_ENDPOINT`  | Datadog OTLP endpoint            |
| `OTEL_EXPORTER_OTLP_HEADERS`   | Contains DD-API-KEY header       |
| `OTEL_RESOURCE_ATTRIBUTES`     | Service name, environment, etc.  |

## Testing

Verify the plugin doesn't cause unwanted git changes:

```bash
./plugins/datadog-otel-setup/scripts/test-configuration.sh
```

Or via justfile:

```bash
just test-plugin-config datadog-otel-setup
```

## Troubleshooting

### No data in Datadog

1. Check API key is set: `echo $DD_API_KEY`
2. Verify settings file was created: `cat .claude/settings.local.json`
3. Check for hook errors in Claude Code output

### Hook not running

1. Ensure plugin is installed in `plugins/` directory
2. Check `hooks/hooks.json` exists and is valid JSON
3. Restart Claude Code session

### Using wrong target file

1. Check `.claude/plugins.settings.yaml` for `target:` setting
2. Override with plugin-specific settings file if needed

## Datadog Setup

1. Create a Datadog account at https://www.datadoghq.com
2. Get your API key from Organization Settings → API Keys
3. Optionally configure the endpoint for your Datadog site:
   - US1: `https://otel.datadoghq.com:4317` (default)
   - US3: `https://otel.us3.datadoghq.com:4317`
   - US5: `https://otel.us5.datadoghq.com:4317`
   - EU: `https://otel.datadoghq.eu:4317`
   - AP1: `https://otel.ap1.datadoghq.com:4317`

## Related

- [Plugin Settings Framework](../../.claude/rules/plugin-settings-framework.md)
- [Claude Code Telemetry](https://docs.anthropic.com/claude-code/docs/telemetry)
- [Datadog OTLP Ingestion](https://docs.datadoghq.com/opentelemetry/otlp_ingest_in_the_agent/)
