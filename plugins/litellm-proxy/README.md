# litellm-proxy

Claude Code plugin that auto-detects and configures a [LiteLLM](https://github.com/BerriAI/litellm) proxy on session start. Routes Claude Code API calls through LiteLLM for multi-provider routing, load balancing, observability, and cost tracking.

## Features

- **Auto-detection** — On session start, detects running LiteLLM proxy and configures Claude Code
- **Multi-provider routing** — Use multiple Anthropic accounts, OpenAI, Gemini, Bedrock, and more
- **Load balancing** — Distribute requests across multiple API keys or providers
- **Observability** — Traces, logs, and metrics via Langfuse, OpenTelemetry, Datadog, or Prometheus
- **Remote proxy support** — Connect to shared LiteLLM instances or Cloudflare AI Gateway
- **Comprehensive skills** — Interactive setup guides for every configuration aspect

## How It Works

On **SessionStart**, the plugin:

1. Reads configuration from YAML config files (project → user → plugin defaults)
2. Checks if a LiteLLM proxy is running (local or remote)
3. Writes `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` to `~/.claude/settings.local.json`
4. Claude Code then routes all API calls through the proxy

## Quick Start

### 1. Install LiteLLM

```bash
pip install 'litellm[proxy]'
```

### 2. Create a config

```bash
mkdir -p ~/.litellm
# Copy the template from the plugin
cp ~/.claude/plugins/litellm-proxy/config/litellm_config.template.yaml ~/.litellm/config.yaml
# Edit with your API keys and providers
```

### 3. Set environment variables

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export LITELLM_MASTER_KEY="sk-litellm-$(openssl rand -hex 16)"
```

### 4. Start the proxy

```bash
litellm --config ~/.litellm/config.yaml --port 4000
```

### 5. Configure the plugin

```yaml
# In ~/.claude/plugins.settings.yaml
litellm-proxy:
  enabled: true
  mode: local
  master_key: "${LITELLM_MASTER_KEY}"
```

### 6. Start Claude Code

The session-start hook auto-configures `ANTHROPIC_BASE_URL`.

## Configuration

Configuration is resolved in order (first match wins):

1. **Project-level**: `${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml`
2. **User-level**: `~/.claude/plugins.settings.yaml`
3. **Plugin defaults**: `config/litellm-proxy.settings.yaml` (bundled)

### Config Format

```yaml
litellm-proxy:
  enabled: true                    # Enable/disable the plugin
  mode: auto                       # auto | local | remote | gateway | disabled
  proxy_host: "http://localhost"   # Local proxy host
  proxy_port: "4000"               # Local proxy port
  master_key: "${LITELLM_MASTER_KEY}"  # Proxy authentication
  remote_url: ""                   # Remote proxy or gateway URL
  anthropic_pass_through: true     # Use /anthropic pass-through endpoint
  config_path: "~/.litellm/config.yaml"  # LiteLLM config file path
```

### Modes

| Mode | Behavior |
|------|----------|
| `auto` | Detect running proxy, configure if found |
| `local` | Always point at local proxy (proxy_host:proxy_port) |
| `remote` | Point at a remote LiteLLM proxy (remote_url) |
| `gateway` | Point at an external gateway like Cloudflare AI Gateway |
| `disabled` | Remove proxy settings, connect directly to Anthropic |

### Secret Resolution

The `master_key` field supports three formats:

| Format | Example | How It Works |
|--------|---------|--------------|
| Env var reference | `${LITELLM_MASTER_KEY}` | Expanded from shell environment |
| 1Password ref | `op://vault/item/field` | Resolved via `op read` |
| Literal | `sk-litellm-abc123` | Used as-is (gitignored configs only) |

## Skills

This plugin includes comprehensive skills for interactive configuration:

| Skill | Purpose |
|-------|---------|
| **setup-litellm** | Install LiteLLM, create config, start proxy, verify connectivity |
| **configure-providers** | Add/manage LLM providers, API keys, load balancing, fallbacks |
| **configure-observability** | Set up traces, logs, metrics (Langfuse, OTEL, Datadog, Prometheus) |
| **configure-remote-proxy** | Connect to remote LiteLLM, Cloudflare AI Gateway, custom gateways |
| **configure-claude-code** | Wire Claude Code to use the proxy, pass-through vs unified endpoints |

## Architecture

```
Claude Code
    │
    ▼
┌─────────────────────┐
│   LiteLLM Proxy     │  ← Observability (Langfuse, OTEL, Datadog)
│   localhost:4000     │
├─────────────────────┤
│ Load Balancer/Router │
└──┬──────┬──────┬────┘
   │      │      │
   ▼      ▼      ▼
Anthropic OpenAI  Gemini  ... (100+ providers)
```

Or with a remote gateway:

```
Claude Code
    │
    ▼
┌──────────────────────────┐
│  Cloudflare AI Gateway   │  ← Caching, rate limiting, analytics
│  (or remote LiteLLM)     │
└──────────┬───────────────┘
           │
           ▼
       Anthropic API
```

## Dependencies

- `jq` — JSON processing
- `yq` — YAML config parsing ([mikefarah/yq](https://github.com/mikefarah/yq))
- `curl` — Health checks
- `op` — 1Password CLI (optional, for `op://` secret references)

## Security

- API keys and master keys are never committed to plugin source
- Writes to `settings.local.json` which should be gitignored
- Prefer env var or 1Password references over literal keys
- The master key authenticates Claude Code to the proxy; provider API keys stay in the proxy config
