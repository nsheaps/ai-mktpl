---
name: configure-claude-code
description: >
  Wire Claude Code to use a LiteLLM proxy or AI gateway. Covers environment
  variable configuration, settings.json and settings.local.json setup,
  API key helpers, pass-through vs unified endpoints, and verification.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Configure Claude Code for LiteLLM Proxy

This skill helps configure Claude Code to route its API calls through a LiteLLM proxy or AI gateway. It covers all the environment variables, settings files, and authentication methods.

## When to Use This Skill

- User wants to point Claude Code at their proxy
- User asks how Claude Code connects to LiteLLM
- User is troubleshooting proxy connectivity
- User wants to switch between direct and proxy connections
- Session-start hook has already configured the proxy but user wants to understand or customize

## How Claude Code Connects to APIs

Claude Code uses these environment variables (in priority order):

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_BASE_URL` | API endpoint URL (default: `https://api.anthropic.com`) |
| `ANTHROPIC_AUTH_TOKEN` | Bearer token sent as `Authorization: Bearer <token>` |
| `ANTHROPIC_API_KEY` | API key sent as `x-api-key` header |
| `ANTHROPIC_CUSTOM_HEADERS` | Additional headers (newline-separated `Name: Value`) |

When using a LiteLLM proxy:

- `ANTHROPIC_BASE_URL` points at the proxy
- `ANTHROPIC_AUTH_TOKEN` carries the LiteLLM master key
- The proxy then forwards to upstream providers with the correct credentials

## Configuration Methods

### Method 1: Automatic (Plugin Hook)

The litellm-proxy plugin's session-start hook automatically configures Claude Code. Just set the plugin settings:

```yaml
# In ~/.claude/plugins.settings.yaml
litellm-proxy:
  enabled: true
  mode: local  # or remote, gateway
  proxy_host: "http://localhost"
  proxy_port: "4000"
  master_key: "${LITELLM_MASTER_KEY}"
  anthropic_pass_through: true
```

The hook writes to `~/.claude/settings.local.json` on each session start.

### Method 2: Manual settings.local.json

Write directly to the local settings file:

```bash
# Create/update settings.local.json
cat > ~/.claude/settings.local.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "sk-litellm-your-master-key"
  }
}
EOF
```

### Method 3: Environment Variables

Set in your shell profile:

```bash
# Add to ~/.bashrc or ~/.zshrc
export ANTHROPIC_BASE_URL="http://localhost:4000/anthropic"
export ANTHROPIC_AUTH_TOKEN="sk-litellm-your-master-key"
```

### Method 4: API Key Helper (for rotating keys)

For dynamic key management:

```bash
# Create helper script
cat > ~/bin/get-litellm-key.sh << 'SCRIPT'
#!/bin/bash
# Return the current LiteLLM master key
echo "${LITELLM_MASTER_KEY:-sk-litellm-default}"
SCRIPT
chmod +x ~/bin/get-litellm-key.sh
```

Configure in settings:

```json
{
  "apiKeyHelper": "~/bin/get-litellm-key.sh",
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000/anthropic",
    "CLAUDE_CODE_API_KEY_HELPER_TTL_MS": "3600000"
  }
}
```

## Pass-Through vs Unified Endpoint

### Pass-Through (`/anthropic` endpoint)

**Recommended for Claude Code.** The proxy forwards requests in native Anthropic Messages API format.

```
Claude Code → POST http://localhost:4000/anthropic/v1/messages → Anthropic API
```

- No format translation needed
- Preserves all Anthropic-specific features (streaming, tool use, etc.)
- Requires `pass_through_endpoints` in LiteLLM config

**LiteLLM config:**

```yaml
general_settings:
  pass_through_endpoints:
    - path: "/anthropic/{endpoint:path}"
      target: "https://api.anthropic.com/{endpoint}"
      headers:
        x-api-key: os.environ/ANTHROPIC_API_KEY
        anthropic-version: "2023-06-01"
```

**Claude Code config:**

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000/anthropic"
  }
}
```

### Unified Endpoint (root `/`)

The proxy translates between OpenAI-compatible format and Anthropic format.

```
Claude Code → POST http://localhost:4000/v1/messages → (translate) → Provider API
```

- Enables multi-provider routing
- May lose some provider-specific features
- Works with load balancing and fallbacks

**Claude Code config:**

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000"
  }
}
```

## Provider-Specific Pass-Through

For Bedrock and Vertex AI through LiteLLM:

### AWS Bedrock

```json
{
  "env": {
    "ANTHROPIC_BEDROCK_BASE_URL": "http://localhost:4000/bedrock",
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "CLAUDE_CODE_SKIP_BEDROCK_AUTH": "1"
  }
}
```

### Google Vertex AI

```json
{
  "env": {
    "ANTHROPIC_VERTEX_BASE_URL": "http://localhost:4000/vertex_ai/v1",
    "ANTHROPIC_VERTEX_PROJECT_ID": "your-gcp-project-id",
    "CLAUDE_CODE_USE_VERTEX": "1",
    "CLAUDE_CODE_SKIP_VERTEX_AUTH": "1",
    "CLOUD_ML_REGION": "us-east5"
  }
}
```

## Verification Steps

### Step 1: Check Current Configuration

```bash
# Check settings.local.json
cat ~/.claude/settings.local.json | jq '.env'

# Check environment
echo "BASE_URL: $ANTHROPIC_BASE_URL"
echo "AUTH_TOKEN: ${ANTHROPIC_AUTH_TOKEN:+set (hidden)}"
```

### Step 2: Test Proxy Health

```bash
curl -s http://localhost:4000/health | jq .
```

### Step 3: Test Pass-Through

```bash
# Test the /anthropic pass-through endpoint directly
curl -X POST http://localhost:4000/anthropic/v1/messages \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

### Step 4: Test via Claude Code

Start a new Claude Code session and check that it works normally. The session-start hook output will confirm the configuration.

## Disabling the Proxy

To go back to direct Anthropic connection:

**Option A: Disable plugin**

```yaml
# In ~/.claude/plugins.settings.yaml
litellm-proxy:
  mode: disabled
```

**Option B: Remove settings manually**

```bash
# Remove proxy env vars from settings.local.json
jq 'del(.env.ANTHROPIC_BASE_URL) | del(.env.ANTHROPIC_AUTH_TOKEN)' \
  ~/.claude/settings.local.json > /tmp/settings.tmp && \
  mv /tmp/settings.tmp ~/.claude/settings.local.json
```

**Option C: Unset environment variables**

```bash
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
```

## Troubleshooting

### "Connection refused" errors

```bash
# Is the proxy running?
curl http://localhost:4000/health
# Is the port correct?
lsof -i :4000
```

### "401 Unauthorized" errors

```bash
# Check master key
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/health
# Verify settings match
cat ~/.claude/settings.local.json | jq '.env.ANTHROPIC_AUTH_TOKEN'
```

### "Model not found" errors

```bash
# List available models
curl -s http://localhost:4000/v1/models -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq '.data[].id'
# Check if anthropic wildcard is configured
grep -A3 'anthropic' ~/.litellm/config.yaml
```

### Requests going to wrong endpoint

```bash
# Verify BASE_URL
cat ~/.claude/settings.local.json | jq '.env.ANTHROPIC_BASE_URL'
# Check if env var is overriding
env | grep ANTHROPIC
```

## Settings File Precedence

Claude Code merges settings from multiple sources (later overrides earlier):

1. `~/.claude/settings.json` — User defaults
2. `.claude/settings.json` — Project settings (committed)
3. `.claude/settings.local.json` — Project local overrides
4. `~/.claude/settings.local.json` — User local overrides (where this plugin writes)
5. Environment variables — Highest priority
