---
name: configure-observability
description: >
  Set up observability for LiteLLM proxy including traces, logs, and metrics.
  Supports Langfuse, OpenTelemetry, Datadog, Prometheus, and custom webhooks.
  Guides through interactive configuration of each observability backend.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Configure Observability

This skill helps set up observability for a LiteLLM proxy, covering traces, logs, and metrics across multiple backends. It enables visibility into LLM usage, costs, latency, and error rates.

## When to Use This Skill

- User wants to add logging/tracing to their LiteLLM proxy
- User asks about monitoring LLM usage or costs
- User mentions Langfuse, OpenTelemetry, Datadog, or Prometheus
- User wants to debug request/response flows through the proxy
- User asks about "observability", "traces", "metrics", "logs"

## Observability Backends

LiteLLM supports multiple observability backends. Ask the user which they prefer:

| Backend | Best For | Self-Hosted? | Traces | Logs | Metrics |
|---------|----------|--------------|--------|------|---------|
| Langfuse | LLM-specific observability | Yes (or cloud) | Yes | Yes | Yes |
| OpenTelemetry | Standard, vendor-agnostic | Collector needed | Yes | Yes | Yes |
| Datadog | Enterprise monitoring | No (SaaS) | Yes | Yes | Yes |
| Prometheus | Metrics-focused | Yes | No | No | Yes |
| Custom Webhook | DIY logging | Yes | No | Yes | No |

## Interactive Setup Flow

### Step 1: Ask User Which Backend(s)

Prompt the user to select one or more observability backends. Multiple can be used simultaneously.

---

## Option A: Langfuse (Recommended for LLM Observability)

Langfuse is purpose-built for LLM observability with prompt management, cost tracking, and evaluation tools.

### Getting API Keys

**Langfuse Cloud (easiest):**

```
1. Sign up at https://cloud.langfuse.com
2. Create a new project
3. Go to Settings → API Keys
4. Copy the Public Key and Secret Key
5. Export:
   export LANGFUSE_PUBLIC_KEY="pk-..."
   export LANGFUSE_SECRET_KEY="sk-..."
   export LANGFUSE_HOST="https://cloud.langfuse.com"
```

**Self-hosted Langfuse:**

```bash
# Docker Compose setup
git clone https://github.com/langfuse/langfuse.git
cd langfuse
docker compose up -d

# Default URL: http://localhost:3000
# Create account, then get API keys from Settings → API Keys
export LANGFUSE_HOST="http://localhost:3000"
```

### LiteLLM Configuration

Add to `~/.litellm/config.yaml`:

```yaml
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]

environment_variables:
  LANGFUSE_PUBLIC_KEY: os.environ/LANGFUSE_PUBLIC_KEY
  LANGFUSE_SECRET_KEY: os.environ/LANGFUSE_SECRET_KEY
  LANGFUSE_HOST: os.environ/LANGFUSE_HOST
```

### What You Get

- Request/response traces with full prompt content
- Token usage and cost tracking per model
- Latency percentiles (p50, p95, p99)
- Error rate monitoring
- User-level usage attribution
- Prompt version management

---

## Option B: OpenTelemetry (OTEL)

Standard, vendor-agnostic telemetry. Works with any OTEL-compatible backend (Jaeger, Zipkin, Grafana Tempo, etc.).

### Prerequisites

You need an OTEL collector or compatible backend:

**Quick OTEL Collector setup:**

```bash
# Using Docker
docker run -d \
  --name otel-collector \
  -p 4317:4317 \
  -p 4318:4318 \
  otel/opentelemetry-collector:latest
```

**With Jaeger (for trace visualization):**

```bash
docker run -d \
  --name jaeger \
  -p 16686:16686 \
  -p 4317:4317 \
  jaegertracing/all-in-one:latest

# Jaeger UI at http://localhost:16686
```

### LiteLLM Configuration

```yaml
litellm_settings:
  success_callback: ["otel"]
  failure_callback: ["otel"]

environment_variables:
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://localhost:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL: "grpc"
  # Optional: add headers for authenticated endpoints
  # OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer your-token"
  OTEL_SERVICE_NAME: "litellm-proxy"
```

### What You Get

- Distributed traces for each LLM request
- Span attributes: model, provider, tokens, latency
- Integration with existing OTEL infrastructure
- Export to any OTEL-compatible backend

---

## Option C: Datadog

Enterprise-grade monitoring with APM, logs, and dashboards.

### Getting API Keys

```
1. Go to https://app.datadoghq.com/organization-settings/api-keys
2. Create a new API key
3. Export:
   export DD_API_KEY="your-dd-api-key"
   export DD_SITE="datadoghq.com"  # or datadoghq.eu, us5.datadoghq.com, etc.
```

### LiteLLM Configuration

```yaml
litellm_settings:
  success_callback: ["datadog"]
  failure_callback: ["datadog"]

environment_variables:
  DD_API_KEY: os.environ/DD_API_KEY
  DD_SITE: os.environ/DD_SITE
```

### Alternative: Datadog via OTEL

Route LiteLLM OTEL data to Datadog's OTLP endpoint:

```yaml
litellm_settings:
  success_callback: ["otel"]
  failure_callback: ["otel"]

environment_variables:
  OTEL_EXPORTER_OTLP_ENDPOINT: "https://otel.datadoghq.com:4317"
  OTEL_EXPORTER_OTLP_HEADERS: "DD-API-KEY=your-dd-api-key"
  OTEL_SERVICE_NAME: "litellm-proxy"
```

### What You Get

- APM traces with flame graphs
- Custom dashboards for LLM metrics
- Alerting on error rates, latency, costs
- Log correlation with traces
- Integration with existing Datadog infrastructure

---

## Option D: Prometheus Metrics

Lightweight metrics collection for dashboards and alerting.

### LiteLLM Built-in Prometheus

LiteLLM exposes Prometheus metrics natively:

```yaml
litellm_settings:
  success_callback: ["prometheus"]
  failure_callback: ["prometheus"]
```

Metrics are available at `http://localhost:4000/metrics`.

### Prometheus Configuration

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'litellm'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:4000']
```

### Grafana Dashboard

After Prometheus is scraping, create Grafana dashboards for:

- `litellm_requests_total` — Total requests by model, status
- `litellm_request_duration_seconds` — Latency histogram
- `litellm_tokens_total` — Token usage by model
- `litellm_spend_total` — Cost by model/user

### What You Get

- Real-time metrics dashboards
- Custom alerting rules (PagerDuty, Slack, etc.)
- Long-term trend analysis
- Integration with existing Prometheus/Grafana stack

---

## Option E: Custom Webhook Logger

Send request/response logs to any HTTP endpoint.

### LiteLLM Configuration

```yaml
litellm_settings:
  success_callback: ["custom_callback_api"]
  failure_callback: ["custom_callback_api"]

environment_variables:
  GENERIC_LOGGER_ENDPOINT: "https://your-webhook.example.com/log"
  GENERIC_LOGGER_HEADERS: '{"Authorization": "Bearer your-token"}'
```

### Webhook Payload

LiteLLM sends JSON payloads containing:

- Request metadata (model, tokens, latency)
- Response content (configurable)
- Error details (for failures)
- User attribution (if configured)

---

## Combining Multiple Backends

You can use multiple callbacks simultaneously:

```yaml
litellm_settings:
  success_callback: ["langfuse", "prometheus", "otel"]
  failure_callback: ["langfuse", "prometheus", "otel"]

environment_variables:
  # Langfuse
  LANGFUSE_PUBLIC_KEY: os.environ/LANGFUSE_PUBLIC_KEY
  LANGFUSE_SECRET_KEY: os.environ/LANGFUSE_SECRET_KEY
  LANGFUSE_HOST: "https://cloud.langfuse.com"
  # OTEL
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://localhost:4317"
  OTEL_SERVICE_NAME: "litellm-proxy"
```

## Verifying Observability

After configuration, restart the proxy and make a test request:

```bash
# Restart proxy
litellm --config ~/.litellm/config.yaml --port 4000

# Make a test request
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-sonnet-4-20250514",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }'

# Check Prometheus metrics
curl http://localhost:4000/metrics 2>/dev/null | grep litellm

# Check Langfuse dashboard
# Visit https://cloud.langfuse.com (or your self-hosted URL)
```

## Security Considerations

- Never commit API keys or secrets to version control
- Use environment variables or secret managers (1Password, Vault)
- Langfuse and Datadog may store prompt content — review data retention policies
- For sensitive environments, use Prometheus (metrics only, no content)
- Consider OTEL with redaction for regulated industries
