---
name: zai-setup
description: >
  Use this skill when the user asks about z.ai, Zhipu AI, setting up z.ai
  API access, getting a z.ai API key, configuring Claude Code to access z.ai
  models via a gateway, or using z.ai's OpenAI-compatible API.
---

# z.ai (Zhipu AI) Setup Guide

[z.ai](https://z.ai/) is the international platform for Zhipu AI (智谱AI), a leading Chinese AI company. They develop the GLM (General Language Model) family of models, which are available via an OpenAI-compatible API.

- **Platform**: <https://z.ai/> (international) / <https://open.bigmodel.cn/> (China)
- **API Docs**: <https://open.bigmodel.cn/dev/api/thirdparty-frame/openai-sdk>
- **API Base URL**: `https://open.bigmodel.cn/api/paas/v4/`

## Getting an API Key

1. Visit <https://open.bigmodel.cn/> and create an account
2. Navigate to **API Keys** in the dashboard
3. Click **Create API Key**
4. Copy the key — it starts with a long alphanumeric string

## API Compatibility

z.ai provides an **OpenAI-compatible API**. You can use the OpenAI SDK or any OpenAI-compatible client:

```bash
# Using curl with OpenAI-compatible endpoint
curl "https://open.bigmodel.cn/api/paas/v4/chat/completions" \
  -H "Authorization: Bearer YOUR_ZHIPU_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4-plus",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

```python
# Using the OpenAI Python SDK
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_ZHIPU_API_KEY",
    base_url="https://open.bigmodel.cn/api/paas/v4/"
)

response = client.chat.completions.create(
    model="glm-4-plus",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

```typescript
// Using the OpenAI Node.js SDK
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: "YOUR_ZHIPU_API_KEY",
  baseURL: "https://open.bigmodel.cn/api/paas/v4/",
});

const response = await client.chat.completions.create({
  model: "glm-4-plus",
  messages: [{ role: "user", content: "Hello!" }],
});
```

## Using z.ai with Claude Code

Claude Code is designed to use Anthropic's Claude models. It does not natively support switching to GLM models. However, you can access z.ai models alongside Claude Code in two ways:

### Option 1: Via Cloudflare AI Gateway (Recommended)

Route z.ai through [Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/) for logging, caching, and cost tracking. See the `cloudflare-ai-gateway` skill for full setup.

```bash
# Use the universal endpoint to proxy z.ai through your gateway
curl "https://gateway.ai.cloudflare.com/v1/ACCT_ID/GATEWAY_ID" \
  -H "Content-Type: application/json" \
  -d '[{
    "provider": "zhipu",
    "endpoint": "https://open.bigmodel.cn/api/paas/v4/chat/completions",
    "headers": { "Authorization": "Bearer YOUR_ZHIPU_API_KEY" },
    "query": {
      "model": "glm-4-plus",
      "messages": [{"role": "user", "content": "Hello"}]
    }
  }]'
```

### Option 2: Direct API Access in Code

Use z.ai directly in your application code via the OpenAI SDK:

```bash
# Store the API key
export ZHIPU_API_KEY="your-key-here"
```

### Option 3: Via OpenRouter

[OpenRouter](https://openrouter.ai/) aggregates many model providers including z.ai/Zhipu models. Configure once and access GLM models alongside hundreds of others:

```bash
export OPENROUTER_API_KEY="your-openrouter-key"

curl "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "zhipu/glm-4-plus",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Claude Code Web Environment Variables

For Claude Code web sessions, you can make z.ai credentials available via environment variables in `.claude/settings.json`:

```json
{
  "env": {
    "ZHIPU_API_KEY": "your-key-here",
    "ZHIPU_BASE_URL": "https://open.bigmodel.cn/api/paas/v4/"
  }
}
```

> **Important**: Do not commit API keys. Use `.claude/settings.local.json` (gitignored) for secrets, or use a secrets manager like 1Password.

## Rate Limits

| Tier | Requests/min | Tokens/min |
|------|-------------|------------|
| Free | 5 | 10,000 |
| Standard | 60 | 300,000 |
| Enterprise | Custom | Custom |

## References

- [z.ai Platform](https://z.ai/)
- [Zhipu Open Platform](https://open.bigmodel.cn/)
- [API Documentation](https://open.bigmodel.cn/dev/api/thirdparty-frame/openai-sdk)
- [OpenRouter Zhipu Models](https://openrouter.ai/models?q=zhipu)
- [Cloudflare AI Gateway Universal Endpoint](https://developers.cloudflare.com/ai-gateway/providers/universal/)
