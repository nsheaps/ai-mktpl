# datadog-otel-setup

Configure Claude Code's OTEL settings for Datadog observability.

## Overview

This plugin configures environment variables in Claude Code's settings file at session start. It uses the plugin settings framework.

## Configuration

Settings in `.claude/plugins.settings.json`:

```json
{
  "datadog-otel-setup": {
    "target": "local",
    "env": {
      "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_LOGS_EXPORTER": "otlp",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel.datadoghq.com:4317",
      "OTEL_RESOURCE_ATTRIBUTES": "service.name=claude-code,deployment.environment=development"
    }
  }
}
```

### Target Options

| Target    | File                          | Use Case                     |
| --------- | ----------------------------- | ---------------------------- |
| `local`   | `.claude/settings.local.json` | Personal config (gitignored) |
| `project` | `.claude/settings.json`       | Shared team config           |
| `user`    | `~/.claude/settings.json`     | Global user config           |

## Environment Variables

| Variable                       | Description                      |
| ------------------------------ | -------------------------------- |
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enables Claude Code telemetry    |
| `OTEL_METRICS_EXPORTER`        | Set to `otlp` for metrics export |
| `OTEL_LOGS_EXPORTER`           | Set to `otlp` for logs export    |
| `OTEL_EXPORTER_OTLP_PROTOCOL`  | Protocol (grpc, http/json, etc.) |
| `OTEL_EXPORTER_OTLP_ENDPOINT`  | Datadog OTLP endpoint            |
| `OTEL_RESOURCE_ATTRIBUTES`     | Service name, environment, etc.  |

## Testing

```bash
just test-plugin-config datadog-otel-setup
```

## Related

- [Plugin Settings Framework](../../docs/plugin-settings-framework.md)
