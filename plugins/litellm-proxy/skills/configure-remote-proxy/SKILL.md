---
name: configure-remote-proxy
description: >
  Configure Claude Code to use a remote LiteLLM proxy or external AI gateway
  such as Cloudflare AI Gateway, a hosted LiteLLM instance, or other
  OpenAI/Anthropic-compatible gateways. Handles URL configuration, authentication,
  and pass-through settings.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Configure Remote Proxy / AI Gateway

This skill helps configure Claude Code to route through a remote LiteLLM proxy or an external AI gateway instead of (or in addition to) a local proxy.

## When to Use This Skill

- User wants to connect to a remote/shared LiteLLM proxy
- User wants to use Cloudflare AI Gateway
- User wants to use another team's or org's AI gateway
- User mentions "remote proxy", "AI gateway", "Cloudflare", "shared proxy"
- User wants centralized LLM management for a team

## Remote Proxy Types

Ask the user which type of remote proxy they want to configure:

| Type | Description | Example URL |
|------|-------------|-------------|
| Remote LiteLLM | LiteLLM proxy running on another machine | `https://litellm.company.com:4000` |
| Cloudflare AI Gateway | Cloudflare's managed AI proxy | `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}` |
| Custom Gateway | Any Anthropic Messages API compatible gateway | `https://ai-proxy.internal.com` |

---

## Option A: Remote LiteLLM Proxy

### Step 1: Get Connection Details

Ask the user for:

1. **Proxy URL** — The base URL of the remote LiteLLM instance
2. **Master Key** — Authentication token (if required)
3. **Pass-through mode** — Whether to use `/anthropic` endpoint

### Step 2: Test Connectivity

```bash
# Test health endpoint
curl -s https://litellm.company.com:4000/health

# Test with authentication
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  https://litellm.company.com:4000/health

# Test Anthropic pass-through
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  https://litellm.company.com:4000/anthropic/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4-20250514", "max_tokens": 10, "messages": [{"role": "user", "content": "Hello"}]}'
```

### Step 3: Configure Plugin

```yaml
# In ~/.claude/plugins.settings.yaml
litellm-proxy:
  enabled: true
  mode: remote
  remote_url: "https://litellm.company.com:4000"
  master_key: "${LITELLM_MASTER_KEY}"
  anthropic_pass_through: true
```

### Step 4: Verify

Restart Claude Code and check:

```bash
cat ~/.claude/settings.local.json | jq '.env.ANTHROPIC_BASE_URL'
# Should show: "https://litellm.company.com:4000/anthropic"
```

---

## Option B: Cloudflare AI Gateway

Cloudflare AI Gateway provides caching, rate limiting, analytics, and fallbacks for AI API calls.

### Step 1: Set Up Cloudflare AI Gateway

```
1. Go to https://dash.cloudflare.com → AI → AI Gateway
2. Create a new gateway (or use existing)
3. Note your:
   - Account ID (from URL or dashboard)
   - Gateway ID (name you chose)
4. The gateway URL pattern is:
   https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}
```

### Step 2: Choose Integration Mode

Cloudflare AI Gateway offers two integration approaches:

**Direct gateway mode** (Claude Code → Cloudflare → Anthropic):

The gateway acts as a transparent pass-through. No LiteLLM needed.

```
URL: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/anthropic
```

**LiteLLM + Cloudflare mode** (Claude Code → LiteLLM → Cloudflare → Anthropic):

LiteLLM routes through Cloudflare for additional features (load balancing, multi-provider, etc.).

```yaml
# In ~/.litellm/config.yaml
model_list:
  - model_name: "anthropic/*"
    litellm_params:
      model: "anthropic/*"
      api_key: os.environ/ANTHROPIC_API_KEY
      api_base: "https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/anthropic"
```

### Step 3: Configure for Direct Gateway Mode

```yaml
# In ~/.claude/plugins.settings.yaml
litellm-proxy:
  enabled: true
  mode: gateway
  remote_url: "https://gateway.ai.cloudflare.com/v1/YOUR_ACCOUNT_ID/YOUR_GATEWAY_ID/anthropic"
```

**Important:** In gateway mode, the plugin sets `ANTHROPIC_BASE_URL` directly to the gateway URL without appending `/anthropic` (the gateway already includes the provider path).

### Step 4: Configure Authentication

Cloudflare AI Gateway forwards your original API key to the upstream provider. Set your Anthropic API key:

```bash
# The API key is sent to Anthropic through Cloudflare
export ANTHROPIC_API_KEY="sk-ant-..."
```

For Claude Code, ensure the API key is available:

```json
// In ~/.claude/settings.local.json (or via environment)
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

### Step 5: Cloudflare Custom Providers

For non-standard providers, Cloudflare supports custom provider configuration:

```
1. In AI Gateway settings → Custom Providers
2. Add your provider's base URL
3. Configure header forwarding
4. Use: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/custom-provider-name
```

---

## Option C: Custom API Gateway

For any gateway that implements the Anthropic Messages API (`/v1/messages`).

### Step 1: Verify Compatibility

The gateway must support:

- `POST /v1/messages` — Anthropic Messages API
- `anthropic-version` header forwarding
- `anthropic-beta` header forwarding
- Streaming via SSE (Server-Sent Events)

Test compatibility:

```bash
curl -X POST https://your-gateway.example.com/v1/messages \
  -H "x-api-key: YOUR_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Step 2: Configure

```yaml
# In ~/.claude/plugins.settings.yaml
litellm-proxy:
  enabled: true
  mode: gateway
  remote_url: "https://your-gateway.example.com"
```

---

## Switching Between Modes

To switch between local and remote proxy:

```yaml
# Switch to remote
litellm-proxy:
  mode: remote
  remote_url: "https://litellm.company.com:4000"

# Switch back to local
litellm-proxy:
  mode: local

# Switch to direct Cloudflare
litellm-proxy:
  mode: gateway
  remote_url: "https://gateway.ai.cloudflare.com/v1/ACCOUNT/GATEWAY/anthropic"

# Disable proxy entirely (direct Anthropic)
litellm-proxy:
  mode: disabled
```

After changing mode, restart Claude Code for the session-start hook to reconfigure.

## Network Considerations

### TLS/SSL

Remote proxies should use HTTPS. If using self-signed certificates:

```bash
# Trust a custom CA certificate
export NODE_EXTRA_CA_CERTS=/path/to/ca-cert.pem
```

### Corporate Proxies

If behind a corporate HTTP proxy:

```bash
export HTTPS_PROXY=https://corporate-proxy.example.com:8080
export NO_PROXY="localhost,127.0.0.1"
```

### Firewall Rules

Ensure your network allows outbound connections to:

- Remote LiteLLM: The proxy's host and port
- Cloudflare: `gateway.ai.cloudflare.com:443`
- Anthropic API (upstream): `api.anthropic.com:443`

## Troubleshooting

### Connection refused

```bash
# Check if the remote proxy is reachable
curl -v https://remote-proxy:4000/health
# Check DNS resolution
nslookup remote-proxy
# Check if port is open
nc -zv remote-proxy 4000
```

### Authentication errors

```bash
# Verify your master key works
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" https://remote-proxy:4000/health
```

### Cloudflare 403 errors

- Verify your account ID and gateway ID are correct
- Check that AI Gateway is enabled in your Cloudflare dashboard
- Ensure your API key is valid for the upstream provider
