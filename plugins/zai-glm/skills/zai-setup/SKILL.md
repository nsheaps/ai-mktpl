---
name: zai-setup
description: >
  Use this skill when the user asks about z.ai, Zhipu AI, setting up z.ai
  API access, getting a z.ai API key, configuring Claude Code to use z.ai
  models directly via the Anthropic-compatible endpoint, routing z.ai through
  Cloudflare AI Gateway or OpenRouter, or using z.ai's OpenAI-compatible API.
---

# z.ai (Zhipu AI) Setup Guide

[z.ai](https://z.ai/) (formerly Zhipu AI / 智谱AI, rebranded July 2025) is a Chinese AI company that develops the GLM (General Language Model) family. They provide both OpenAI-compatible and Anthropic-compatible API endpoints.

- **Platform**: <https://z.ai/> (international) / <https://open.bigmodel.cn/> (China)
- **Docs**: <https://docs.z.ai/>
- **API Base URL (International)**: `https://api.z.ai/api/paas/v4/`
- **API Base URL (China)**: `https://open.bigmodel.cn/api/paas/v4/`
- **Anthropic-compatible endpoint**: `https://api.z.ai/api/anthropic`
- **Pricing**: <https://docs.z.ai/guides/overview/pricing>

## Getting an API Key

1. Visit <https://z.ai/model-api> (international) or <https://open.bigmodel.cn/> (China)
2. Create an account (email or phone verification required)
3. Navigate to **API Keys** in your account dashboard
4. Generate and copy your API key

## API Compatibility

z.ai provides **two** compatible API formats:

### OpenAI-Compatible API

```bash
curl "https://api.z.ai/api/paas/v4/chat/completions" \
  -H "Authorization: Bearer YOUR_ZHIPU_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4.7",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

```python
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_ZHIPU_API_KEY",
    base_url="https://api.z.ai/api/paas/v4/"
)

response = client.chat.completions.create(
    model="glm-4.7",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

```typescript
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: "YOUR_ZHIPU_API_KEY",
  baseURL: "https://api.z.ai/api/paas/v4/",
});

const response = await client.chat.completions.create({
  model: "glm-4.7",
  messages: [{ role: "user", content: "Hello!" }],
});
```

### Anthropic-Compatible API

z.ai also provides an endpoint that speaks the Anthropic Messages API protocol. This is what enables direct Claude Code integration.

## Using z.ai with Claude Code

### Option 1: Direct via Anthropic-Compatible Endpoint (Recommended)

z.ai provides a native Anthropic-compatible endpoint at `https://api.z.ai/api/anthropic`. Claude Code can connect directly — no proxy needed.

**In `~/.claude/settings.json`:**

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "your-zai-api-key",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

**Or via shell alias:**

```bash
# Add to ~/.bashrc or ~/.zshrc
zaiclaude() {
  ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic \
  ANTHROPIC_AUTH_TOKEN="your-zai-api-key" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "$@"
}
```

**Optional model mapping** — map Claude Code's model slots to specific GLM models:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "your-zai-api-key",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

| Variable                                   | Purpose                                                    |
| ------------------------------------------ | ---------------------------------------------------------- |
| `ANTHROPIC_BASE_URL`                       | Points Claude Code to z.ai's Anthropic endpoint            |
| `ANTHROPIC_AUTH_TOKEN`                     | Your z.ai API key                                          |
| `ANTHROPIC_API_KEY`                        | Set to `""` to avoid conflicts with existing Anthropic key |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Prevents background traffic to Anthropic servers           |
| `ANTHROPIC_DEFAULT_SONNET_MODEL`           | GLM model for the "Sonnet" slot                            |
| `ANTHROPIC_DEFAULT_OPUS_MODEL`             | GLM model for the "Opus" slot                              |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL`            | GLM model for the "Haiku" slot                             |

> **Note**: See <https://docs.z.ai/scenario-example/develop-tools/claude> for z.ai's official Claude Code integration guide.

### Option 2: Via Cloudflare AI Gateway

Route z.ai through [Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/) for logging, caching, and cost tracking. See the `cloudflare-ai-gateway` skill for full setup.

```bash
# Use the universal endpoint to proxy z.ai through your gateway
curl "https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID" \
  -H "Content-Type: application/json" \
  -d '[{
    "provider": "zhipu",
    "endpoint": "https://api.z.ai/api/paas/v4/chat/completions",
    "headers": { "Authorization": "Bearer YOUR_ZHIPU_API_KEY" },
    "query": {
      "model": "glm-4.7",
      "messages": [{"role": "user", "content": "Hello"}]
    }
  }]'
```

### Option 3: Via OpenRouter

[OpenRouter](https://openrouter.ai/) aggregates many model providers including z.ai/Zhipu models:

```bash
curl "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "zhipu/glm-4.7",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Claude Code Web Sessions

For Claude Code web sessions, set environment variables in `.claude/settings.local.json` (gitignored):

```json
{
  "env": {
    "ZHIPU_API_KEY": "your-key-here",
    "ZHIPU_BASE_URL": "https://api.z.ai/api/paas/v4/"
  }
}
```

> **Important**: Never put API keys in `settings.json` (committed). Always use `settings.local.json` (gitignored) or a secrets manager like 1Password.

## Coding Plan

z.ai offers a **Coding Plan** subscription for enhanced coding model access:

- **Lite**: $10/mo
- **Pro**: $30/mo
- **Endpoint**: `https://api.z.ai/api/coding/paas/v4`

## References

- [z.ai Platform](https://z.ai/)
- [z.ai Developer Docs](https://docs.z.ai/)
- [z.ai Pricing](https://docs.z.ai/guides/overview/pricing)
- [Claude Code Integration Guide](https://docs.z.ai/scenario-example/develop-tools/claude)
- [OpenRouter Zhipu Models](https://openrouter.ai/models?q=zhipu)
- [Cloudflare AI Gateway Universal Endpoint](https://developers.cloudflare.com/ai-gateway/providers/universal/)
- [z.ai on GitHub](https://github.com/zai-org)
- [z.ai on Hugging Face](https://huggingface.co/zai-org)
