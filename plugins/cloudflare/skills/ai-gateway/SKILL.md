---
name: cloudflare-ai-gateway
description: >
  Use this skill when the user asks about Cloudflare AI Gateway, proxying AI
  API requests through Cloudflare, setting up Claude Code with AI Gateway,
  configuring ANTHROPIC_BASE_URL, routing AI traffic through a gateway for
  logging/caching/rate-limiting, cost tracking for AI APIs, connecting Claude
  Code to OpenRouter or z.ai via a gateway, or managing AI Gateway with Pulumi.
---

# Cloudflare AI Gateway

Cloudflare AI Gateway is a managed proxy that sits between your application and AI inference providers (Anthropic, OpenAI, OpenRouter, z.ai, etc.). It provides observability, caching, rate limiting, cost tracking, and fallback routing — without changing your application code beyond updating the base URL.

- **Docs**: <https://developers.cloudflare.com/ai-gateway/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/ai/ai-gateway>
- **API**: <https://developers.cloudflare.com/api/resources/ai_gateway/>

## Key Features

| Feature            | Description                                                          |
| ------------------ | -------------------------------------------------------------------- |
| **Logging**        | Full request/response logging with metadata (tokens, latency, cost)  |
| **Caching**        | Cache identical prompts to reduce cost and latency; configurable TTL |
| **Rate Limiting**  | Per-gateway or per-user rate limits to control spend                 |
| **Cost Tracking**  | Real-time cost analytics across all providers                        |
| **Retries**        | Automatic retries with backoff on provider errors                    |
| **Fallbacks**      | Route to a backup provider if the primary fails                      |
| **Real-time Logs** | Stream logs in the dashboard for debugging                           |

## How It Works

AI Gateway acts as a reverse proxy. You replace the provider's base URL with the gateway URL:

```
https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/{provider}
```

Supported `{provider}` values include:

- `anthropic` — Anthropic (Claude models)
- `openai` — OpenAI (GPT models)
- `openrouter` — OpenRouter (multi-model aggregator)
- `workers-ai` — Cloudflare Workers AI
- `azure-openai` — Azure OpenAI Service
- `google-ai-studio` — Google AI Studio (Gemini)
- `huggingface` — Hugging Face Inference API
- `groq` — Groq
- `cohere` — Cohere
- `mistral` — Mistral AI
- `perplexity-ai` — Perplexity
- Custom providers via the universal endpoint

### Universal Endpoint

For providers not in the built-in list (like z.ai), use the **universal endpoint**:

```
POST https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}
```

With a body that specifies the provider and target URL. See the [universal endpoint docs](https://developers.cloudflare.com/ai-gateway/providers/universal/).

## Setting Up Claude Code CLI with AI Gateway

### Step 1: Create an AI Gateway

In the Cloudflare dashboard or via Pulumi (see below), create a gateway. Note your:

- **Account ID** (found in dashboard URL or API)
- **Gateway ID** (the slug you chose, e.g., `claude-code`)

### Step 2: Configure Claude Code

Set the `ANTHROPIC_BASE_URL` environment variable to route all Anthropic API calls through the gateway:

```bash
# In your shell profile (~/.bashrc, ~/.zshrc, etc.)
export ANTHROPIC_BASE_URL="https://gateway.ai.cloudflare.com/v1/YOUR_ACCOUNT_ID/YOUR_GATEWAY_ID/anthropic"
```

Or in a project's `.env` file:

```env
ANTHROPIC_BASE_URL=https://gateway.ai.cloudflare.com/v1/YOUR_ACCOUNT_ID/YOUR_GATEWAY_ID/anthropic
```

Or in Claude Code's settings (`~/.claude/settings.json` or `.claude/settings.json`):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://gateway.ai.cloudflare.com/v1/YOUR_ACCOUNT_ID/YOUR_GATEWAY_ID/anthropic"
  }
}
```

### Step 3: Verify

```bash
# Start Claude Code — it should work transparently
claude

# Check the AI Gateway dashboard for logged requests
# https://dash.cloudflare.com/?to=/:account/ai/ai-gateway/YOUR_GATEWAY_ID
```

Your `ANTHROPIC_API_KEY` is still sent in the `x-api-key` header as normal. The gateway proxies it to Anthropic. The gateway itself authenticates via your Cloudflare account.

## Setting Up Claude Code on the Web with AI Gateway

Claude Code on the web (claude.ai) uses Anthropic's infrastructure directly and **does not support** `ANTHROPIC_BASE_URL` overrides. You cannot route claude.ai web traffic through AI Gateway.

However, for **Claude Code web sessions** (code.claude.com / Claude Code in the browser IDE), you can set environment variables via:

1. **SessionStart hooks** in your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "echo 'ANTHROPIC_BASE_URL=https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID/anthropic' >> \"$CLAUDE_ENV_FILE\""
      }
    ]
  }
}
```

2. **Environment variables** in `.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID/anthropic"
  }
}
```

> **Note**: Claude Code on the web must have network access to `gateway.ai.cloudflare.com`. This works in most environments but may be blocked in restricted network setups.

## Routing to Other Providers via AI Gateway

### OpenRouter via AI Gateway

[OpenRouter](https://openrouter.ai/) aggregates 200+ models. Route through AI Gateway for logging:

```bash
# The gateway proxies to OpenRouter's API
export OPENROUTER_BASE_URL="https://gateway.ai.cloudflare.com/v1/YOUR_ACCOUNT_ID/YOUR_GATEWAY_ID/openrouter"
```

Use with any OpenAI-compatible client:

```bash
curl "https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID/openrouter/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-sonnet-4-20250514",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### z.ai via AI Gateway (Universal Endpoint)

[z.ai](https://z.ai/) (Zhipu AI) provides GLM models with an OpenAI-compatible API. Route through the universal endpoint:

```bash
curl "https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID" \
  -H "Content-Type: application/json" \
  -d '[{
    "provider": "zhipu",
    "endpoint": "https://open.bigmodel.cn/api/paas/v4/chat/completions",
    "headers": {
      "Authorization": "Bearer YOUR_ZHIPU_API_KEY",
      "Content-Type": "application/json"
    },
    "query": {
      "model": "glm-4-plus",
      "messages": [{"role": "user", "content": "Hello"}]
    }
  }]'
```

Alternatively, configure z.ai as a custom provider in the AI Gateway dashboard and use:

```
https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID/zhipu
```

### Fallback Chains

AI Gateway supports fallback routing — if the primary provider fails, automatically try another:

```bash
curl "https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "provider": "anthropic",
      "endpoint": "messages",
      "headers": { "x-api-key": "YOUR_ANTHROPIC_KEY" },
      "query": { "model": "claude-sonnet-4-20250514", "max_tokens": 1024, "messages": [{"role": "user", "content": "Hello"}] }
    },
    {
      "provider": "openai",
      "endpoint": "chat/completions",
      "headers": { "Authorization": "Bearer YOUR_OPENAI_KEY" },
      "query": { "model": "gpt-4o", "messages": [{"role": "user", "content": "Hello"}] }
    }
  ]'
```

## Infrastructure Setup

### No Native Pulumi/Terraform Resource

As of March 2026, there is **no native Pulumi or Terraform resource** for Cloudflare AI Gateway. The upstream Terraform provider tracks this as [issue #6720](https://github.com/cloudflare/terraform-provider-cloudflare/issues/6720).

Create the gateway via the **dashboard** or the **Cloudflare REST API**.

### Create via Dashboard

1. Go to [AI Gateway](https://dash.cloudflare.com/?to=/:account/ai/ai-gateway)
2. Click **Create Gateway**
3. Set a name/slug (e.g., `claude-code`) — this becomes the `{gateway_id}` in URLs
4. Configure rate limiting and caching as desired

### Create via REST API

```bash
# One-time setup — create the gateway
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai-gateway/gateways" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "claude-code",
    "slug": "claude-code",
    "rate_limiting_interval": 60,
    "rate_limiting_limit": 200,
    "rate_limiting_technique": "fixed",
    "cache_ttl": 0
  }'
```

### Reference in Pulumi

Since no native resource exists, reference the gateway by name in your Pulumi stack outputs:

```typescript
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const cfConfig = new pulumi.Config("cloudflare");
const accountId = cfConfig.require("accountId");
const aiGatewayName = config.get("aiGatewayName") ?? "claude-code";

// Gateway must be created via dashboard or API first
export const aiGatewayId = aiGatewayName;
export const anthropicBaseUrl = pulumi.interpolate`https://gateway.ai.cloudflare.com/v1/${accountId}/${aiGatewayName}/anthropic`;
export const openrouterBaseUrl = pulumi.interpolate`https://gateway.ai.cloudflare.com/v1/${accountId}/${aiGatewayName}/openrouter`;
```

## Monitoring and Analytics

Once configured, the AI Gateway dashboard provides:

- **Request logs**: Every request with provider, model, tokens, latency, status
- **Cost analytics**: Aggregated spend by provider, model, and time period
- **Cache hit rate**: How many requests were served from cache
- **Error rates**: Failed requests by provider with error details
- **Real-time streaming**: Live log tail for debugging

Access at: `https://dash.cloudflare.com/?to=/:account/ai/ai-gateway/YOUR_GATEWAY_ID`

## Troubleshooting

| Issue                          | Solution                                                                                    |
| ------------------------------ | ------------------------------------------------------------------------------------------- |
| `401 Unauthorized`             | Your API key is passed through to the provider. Verify `ANTHROPIC_API_KEY` is set correctly |
| `403 Forbidden`                | Check that your Cloudflare account has AI Gateway enabled                                   |
| `429 Too Many Requests`        | Hit the gateway rate limit. Increase `rateLimitingLimit` or wait                            |
| `502 Bad Gateway`              | The upstream provider is down. Check provider status pages                                  |
| Requests not appearing in logs | Verify the URL path is correct: `/v1/{account_id}/{gateway_id}/{provider}`                  |
| Claude Code hangs on start     | Ensure `ANTHROPIC_BASE_URL` does not have a trailing slash                                  |

## References

- [AI Gateway Overview](https://developers.cloudflare.com/ai-gateway/)
- [Supported Providers](https://developers.cloudflare.com/ai-gateway/providers/)
- [Universal Endpoint](https://developers.cloudflare.com/ai-gateway/providers/universal/)
- [Caching](https://developers.cloudflare.com/ai-gateway/configuration/caching/)
- [Rate Limiting](https://developers.cloudflare.com/ai-gateway/configuration/rate-limiting/)
- [Logging](https://developers.cloudflare.com/ai-gateway/observability/logging/)
- [Analytics](https://developers.cloudflare.com/ai-gateway/observability/analytics/)
- [Cloudflare AI Gateway API](https://developers.cloudflare.com/api/resources/ai_gateway/)
- [Terraform provider issue #6720](https://github.com/cloudflare/terraform-provider-cloudflare/issues/6720) (no native IaC resource yet)
- [Claude Code Environment Variables](https://docs.anthropic.com/en/docs/claude-code/settings#environment-variables)
