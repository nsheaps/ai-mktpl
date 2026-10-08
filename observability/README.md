# Claude Code Observability Stack

A Docker Compose stack for collecting and visualizing Claude Code telemetry data locally using OpenTelemetry, Prometheus, Loki, and Grafana.

## Architecture

```
┌─────────────────┐     OTLP (gRPC/HTTP)     ┌──────────────────┐
│   Claude Code   │ ───────────────────────► │  OTEL Collector  │
└─────────────────┘                          └────────┬─────────┘
                                                      │
                                    ┌─────────────────┼─────────────────┐
                                    │                 │                 │
                                    ▼                 ▼                 ▼
                            ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
                            │  Prometheus  │  │     Loki     │  │    Debug     │
                            │  (Metrics)   │  │   (Events)   │  │   (stdout)   │
                            └──────┬───────┘  └──────┬───────┘  └──────────────┘
                                   │                 │
                                   └────────┬────────┘
                                            │
                                            ▼
                                    ┌──────────────┐
                                    │   Grafana    │
                                    │ (Dashboard)  │
                                    └──────────────┘
```

## Quick Start

### 1. Start the Stack

```bash
cd observability
docker compose up -d
```

### 2. Configure Claude Code

Add the following environment variables to your shell configuration (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
# Enable telemetry (required)
export CLAUDE_CODE_ENABLE_TELEMETRY=1

# Configure OTLP exporters
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp

# OTLP endpoint (gRPC)
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

Reload your shell:

```bash
source ~/.bashrc  # or ~/.zshrc
```

### 3. Access Grafana

Open [http://localhost:3000](http://localhost:3000) in your browser.

- **Username:** `admin`
- **Password:** `admin`

Navigate to **Dashboards → Claude Code** to view your metrics.

## Services

| Service        | Port                     | Description                         |
| -------------- | ------------------------ | ----------------------------------- |
| OTEL Collector | 4317 (gRPC), 4318 (HTTP) | Receives telemetry from Claude Code |
| Prometheus     | 9090                     | Metrics storage and querying        |
| Loki           | 3100                     | Log/event storage                   |
| Grafana        | 3000                     | Visualization and dashboards        |

## Configuration Options

### User-Level Configuration (Recommended)

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, `~/.profile`):

```bash
# Required: Enable telemetry
export CLAUDE_CODE_ENABLE_TELEMETRY=1

# Exporters
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp

# Protocol and endpoint
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317

# Optional: Reduce export intervals for faster feedback (development)
export OTEL_METRIC_EXPORT_INTERVAL=10000   # 10 seconds (default: 60000)
export OTEL_LOGS_EXPORT_INTERVAL=5000      # 5 seconds (default: 5000)

# Optional: Include version in metrics
export OTEL_METRICS_INCLUDE_VERSION=true

# Optional: Log user prompts (privacy warning - prompts will be stored)
# export OTEL_LOG_USER_PROMPTS=1
```

### Claude Code Settings File

Alternatively, add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4317"
  }
}
```

### HTTP Protocol (Alternative)

If you prefer HTTP/JSON instead of gRPC:

```bash
export OTEL_EXPORTER_OTLP_PROTOCOL=http/json
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

### Separate Endpoints for Metrics and Logs

```bash
export OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://localhost:4317
export OTEL_EXPORTER_OTLP_LOGS_PROTOCOL=http/json
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://localhost:4318/v1/logs
```

## Available Metrics

Claude Code exports the following metrics:

| Metric                                | Description           | Attributes                                             |
| ------------------------------------- | --------------------- | ------------------------------------------------------ |
| `claude_code.session.count`           | Sessions started      | -                                                      |
| `claude_code.cost.usage`              | Cost in USD           | `model`                                                |
| `claude_code.token.usage`             | Tokens used           | `model`, `type` (input/output/cacheRead/cacheCreation) |
| `claude_code.lines_of_code.count`     | Lines changed         | `type` (added/removed)                                 |
| `claude_code.commit.count`            | Git commits           | -                                                      |
| `claude_code.pull_request.count`      | PRs created           | -                                                      |
| `claude_code.code_edit_tool.decision` | Edit decisions        | `tool`, `decision`, `language`                         |
| `claude_code.active_time.total`       | Active time (seconds) | -                                                      |

## Available Events

Events are exported via the logs pipeline:

| Event                       | Description          | Key Attributes                             |
| --------------------------- | -------------------- | ------------------------------------------ |
| `claude_code.user_prompt`   | User input           | `prompt_length`, `prompt` (if enabled)     |
| `claude_code.tool_result`   | Tool execution       | `tool_name`, `success`, `duration_ms`      |
| `claude_code.api_request`   | API calls            | `model`, `cost_usd`, `duration_ms`, tokens |
| `claude_code.api_error`     | API errors           | `model`, `error`, `status_code`            |
| `claude_code.tool_decision` | Permission decisions | `tool_name`, `decision`, `source`          |

## Troubleshooting

### Verify the Stack is Running

```bash
docker compose ps
```

All services should show `Up` status.

### Check OTEL Collector Logs

```bash
docker compose logs otel-collector
```

### Test OTLP Endpoint

```bash
# gRPC health check
grpcurl -plaintext localhost:4317 grpc.health.v1.Health/Check

# Or simply check if port is open
nc -zv localhost 4317
```

### No Metrics Appearing

1. Verify `CLAUDE_CODE_ENABLE_TELEMETRY=1` is set
2. Check the OTEL Collector logs for incoming data
3. Verify the endpoint is reachable from your shell
4. Try console exporter first to verify telemetry is working:

```bash
export OTEL_METRICS_EXPORTER=console
export OTEL_METRIC_EXPORT_INTERVAL=5000
```

### Prometheus Not Receiving Metrics

Check the OTEL Collector debug output:

```bash
docker compose logs otel-collector | grep -i metric
```

### Reset All Data

```bash
docker compose down -v
docker compose up -d
```

## Resource Attributes

All telemetry includes these resource attributes:

| Attribute         | Description                         |
| ----------------- | ----------------------------------- |
| `service.name`    | `claude-code`                       |
| `service.version` | Claude Code version                 |
| `os.type`         | Operating system                    |
| `os.version`      | OS version                          |
| `host.arch`       | CPU architecture                    |
| `session.id`      | Unique session ID                   |
| `terminal.type`   | Terminal type (iTerm, vscode, etc.) |

## Customizing the Dashboard

The pre-built dashboard is located at:

```
grafana/provisioning/dashboards/claude-code.json
```

You can modify it directly, or:

1. Edit the dashboard in Grafana UI
2. Export via **Dashboard Settings → JSON Model**
3. Save to the dashboards directory

Changes will be picked up automatically (30-second interval).

## Adding Organization/Team Labels

For multi-team environments, add resource attributes:

```bash
export OTEL_RESOURCE_ATTRIBUTES="department=engineering,team.id=platform"
```

These will appear as labels on all metrics and events.

## Security Notes

- Telemetry is **opt-in** - requires explicit `CLAUDE_CODE_ENABLE_TELEMETRY=1`
- User prompts are **redacted by default** - enable with `OTEL_LOG_USER_PROMPTS=1`
- Sensitive data (API keys, file contents) is **never included**
- This stack is for **local use only** - no authentication is configured

## Stopping the Stack

```bash
docker compose down
```

To also remove stored data:

```bash
docker compose down -v
```

## References

- [Claude Code Monitoring Documentation](https://code.claude.com/docs/en/monitoring-usage)
- [OpenTelemetry Configuration](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
