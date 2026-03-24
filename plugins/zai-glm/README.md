# z.ai / GLM Models Plugin

Skills for using [z.ai](https://z.ai/) (Zhipu AI) GLM models and configuring access from Claude Code environments.

## Skills

| Skill        | Description                                                                                                                           |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `zai-setup`  | Setting up z.ai API access, getting API keys, configuring Claude Code to access z.ai via gateways (Cloudflare AI Gateway, OpenRouter) |
| `glm-models` | GLM model family reference — capabilities, pricing, selection guide for GLM-4, GLM-4V, CogView, CogVideoX, embeddings                 |

## About z.ai

z.ai is the international platform for Zhipu AI (智谱AI), one of China's leading AI companies. Their GLM model family includes:

- **Text models**: GLM-4-Plus (128K), GLM-4-Long (1M context), GLM-4-Flash (free)
- **Vision models**: GLM-4V-Plus for image understanding
- **Embeddings**: embedding-3 for semantic search
- **Image generation**: CogView-3 series
- **Video generation**: CogVideoX

All models are accessible via an OpenAI-compatible API, making them easy to integrate with existing tools and SDKs.

## Integration with Claude Code

While Claude Code runs Anthropic's Claude models natively, z.ai models can be accessed from Claude Code sessions via:

1. **Cloudflare AI Gateway** — Route z.ai through a unified gateway (see the `cloudflare` plugin's `cloudflare-ai-gateway` skill)
2. **OpenRouter** — Access GLM models through OpenRouter's aggregated API
3. **Direct API** — Call z.ai's OpenAI-compatible endpoint from application code
