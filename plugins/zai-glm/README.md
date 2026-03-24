# z.ai / GLM Models Plugin

Skills for using [z.ai](https://z.ai/) (formerly Zhipu AI) GLM models and configuring access from Claude Code environments.

## Skills

| Skill        | Description                                                                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `zai-setup`  | Setting up z.ai API access, getting API keys, configuring Claude Code via the Anthropic-compatible endpoint, Cloudflare AI Gateway, or OpenRouter       |
| `glm-models` | GLM model family reference — capabilities, pricing, selection guide for GLM-5, GLM-4.7, GLM-4.6, GLM-4.5, vision models, CogView, CogVideoX, embeddings |

## About z.ai

z.ai (rebranded from Zhipu AI in July 2025) is one of China's leading AI companies. Their GLM model family includes:

- **Flagship**: GLM-5 (745B MoE, agentic), GLM-4.7 (coding-focused), GLM-4.5 (hybrid reasoning)
- **Vision**: GLM-4.6V for image understanding
- **Embeddings**: embedding-3 for semantic search
- **Image generation**: GLM-Image, CogView-3 series
- **Video generation**: CogVideoX

All recent models are open-weight under MIT license. Free tiers available (`glm-4.5-flash`, `glm-4.7-flash`, `glm-4.6v-flash`).

## Integration with Claude Code

z.ai provides a **native Anthropic-compatible endpoint** (`https://api.z.ai/api/anthropic`), enabling direct Claude Code integration without a proxy:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "your-zai-api-key",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

Additional integration options:

1. **Cloudflare AI Gateway** — Route z.ai through a unified gateway (see the `cloudflare` plugin's `cloudflare-ai-gateway` skill)
2. **OpenRouter** — Access GLM models through OpenRouter's aggregated API
3. **Direct API** — Call z.ai's OpenAI-compatible endpoint from application code

## Related Plugins

- **cloudflare** — `cloudflare-ai-gateway` skill for proxying z.ai through Cloudflare AI Gateway
