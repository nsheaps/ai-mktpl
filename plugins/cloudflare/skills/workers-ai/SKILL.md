---
name: cloudflare-workers-ai
description: >
  Use this skill when the user asks about Cloudflare Workers AI, running AI
  inference on Cloudflare's edge, using AI models in Workers, or managing
  Workers AI resources with Pulumi.
---

# Cloudflare Workers AI

Workers AI lets you run AI models on Cloudflare's GPU-powered edge network. Access open-source models (LLMs, image generation, embeddings, speech-to-text) directly from Workers with zero infrastructure management.

- **Docs**: <https://developers.cloudflare.com/workers-ai/>
- **Model Catalog**: <https://developers.cloudflare.com/workers-ai/models/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/ai/workers-ai>
- **Pulumi resource**: `cloudflare.WorkersScript` with `aiBinding`

## Usage in Workers

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const response = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
      messages: [{ role: "user", content: "What is Cloudflare?" }],
    });
    return Response.json(response);
  },
};

interface Env {
  AI: Ai;
}
```

### Wrangler Config

```toml
[ai]
binding = "AI"
```

## Popular Models

| Model | Task | ID |
|-------|------|----|
| Llama 3.1 8B | Text generation | `@cf/meta/llama-3.1-8b-instruct` |
| Mistral 7B | Text generation | `@cf/mistral/mistral-7b-instruct-v0.2` |
| BAAI BGE | Text embeddings | `@cf/baai/bge-base-en-v1.5` |
| Stable Diffusion XL | Image generation | `@cf/stabilityai/stable-diffusion-xl-base-1.0` |
| Whisper | Speech-to-text | `@cf/openai/whisper` |

## REST API

Workers AI also has a REST API (no Worker needed):

```bash
curl "https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/run/@cf/meta/llama-3.1-8b-instruct" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -d '{"messages": [{"role": "user", "content": "Hello"}]}'
```

## Pulumi IaC

```typescript
// Workers AI is accessed via a binding on a Worker — no separate resource needed
const worker = new cloudflare.WorkersScript("ai-worker", {
  accountId,
  name: "ai-worker",
  content: workerScript,
  module: true,
  // AI binding is automatic when using the AI API in the Worker
});
```

## Pricing

| Tier | Neurons/day | Cost |
|------|-------------|------|
| Free | 10,000 | $0 |
| Paid | Unlimited | $0.011 per 1,000 neurons |

Neurons are a normalized unit of compute across all models.

## References

- [Workers AI Docs](https://developers.cloudflare.com/workers-ai/)
- [Model Catalog](https://developers.cloudflare.com/workers-ai/models/)
- [REST API](https://developers.cloudflare.com/workers-ai/get-started/rest-api/)
- [Pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
