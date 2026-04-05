---
name: glm-models
description: >
  Use this skill when the user asks about GLM models, GLM-5, GLM-4.7, GLM-4.6,
  GLM-4.5, GLM-4V, ChatGLM, CogView, CogVideoX, z.ai model capabilities,
  model selection for different tasks, or comparing GLM models.
---

# GLM Model Family

The GLM (General Language Model) family is developed by z.ai (formerly Zhipu AI / 智谱AI). These models support text generation, vision, code, embeddings, image generation, and video generation. All recent models are open-weight under MIT license.

- **Docs**: <https://docs.z.ai/>
- **API Base URL**: `https://api.z.ai/api/paas/v4/`
- **Pricing**: <https://docs.z.ai/guides/overview/pricing>

## Flagship Text Models

| Model           | Architecture           | Context            | Key Features                                                  |
| --------------- | ---------------------- | ------------------ | ------------------------------------------------------------- |
| `glm-5`         | ~745B MoE (44B active) | 200K in / 128K out | Agentic engineering, tool streaming, long-horizon tasks, MIT  |
| `glm-5-turbo`   | Same, optimized        | 200K in / 128K out | Improved stability for long-chain agent tasks                 |
| `glm-4.7`       | ~400B MoE              | 200K in / 128K out | Coding-focused, Preserved Thinking, Turn-level Thinking, MIT  |
| `glm-4.7-flash` | Lightweight            | Reduced            | Free tier, lighter capability                                 |
| `glm-4.6`       | 355B total             | 200K               | Strong code benchmarks, agent frameworks, MIT                 |
| `glm-4.5`       | 355B / 32B active      | 128K               | Hybrid reasoning (thinking/non-thinking modes), deep thinking |
| `glm-4.5-x`     | Premium tier           | 128K               | Higher capability, premium pricing                            |
| `glm-4.5-air`   | 106B / 12B active      | 128K               | Compact variant of GLM-4.5                                    |
| `glm-4.5-flash` | Lightweight            | 128K               | Free tier                                                     |

### Thinking Mode

GLM-4.5+ models support **hybrid reasoning** — toggle between deep thinking and instant response:

```json
{
  "model": "glm-4.7",
  "messages": [{ "role": "user", "content": "Solve this step by step" }],
  "thinking": { "type": "enabled" }
}
```

- **Preserved Thinking** (GLM-4.7): Retains thinking blocks across multi-turn conversations
- **Turn-level Thinking** (GLM-4.7): Per-turn control — disable for lightweight requests, enable for complex tasks
- **Tool Streaming** (GLM-5): Stream output during tool calling (`tool_stream: true`)

## Vision / Multimodal Models

| Model            | Parameters        | Context | Description                            |
| ---------------- | ----------------- | ------- | -------------------------------------- |
| `glm-4.6v`       | 106B / 12B active | 128K    | Vision understanding, function calling |
| `glm-4.6v-flash` | 9B                | —       | Free, open weights, commercial license |
| `glm-4.5v`       | 106B VLM          | —       | Vision-language model                  |

### Vision API Example

```bash
curl "https://api.z.ai/api/paas/v4/chat/completions" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4.6v",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "What is in this image?"},
        {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}}
      ]
    }]
  }'
```

## Specialized Models

| Model             | Category         | Description                |
| ----------------- | ---------------- | -------------------------- |
| `glm-image`       | Image generation | Text-to-image (Jan 2026)   |
| `glm-ocr`         | OCR              | Document and image OCR     |
| `cogview-3-plus`  | Image gen        | High-quality text-to-image |
| `cogvideox`       | Video gen        | Text-to-video generation   |
| `cogvideox-flash` | Video gen        | Fast video generation      |

## Embedding Models

| Model         | Dimensions | Description                     |
| ------------- | ---------- | ------------------------------- |
| `embedding-3` | 2048       | General-purpose text embeddings |
| `embedding-2` | 1024       | Previous generation embeddings  |

```bash
curl "https://api.z.ai/api/paas/v4/embeddings" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "embedding-3",
    "input": "What is machine learning?"
  }'
```

## Model Selection Guide

| Use Case            | Recommended Model | Why                                     |
| ------------------- | ----------------- | --------------------------------------- |
| Agentic tasks       | `glm-5`           | Tool streaming, long-horizon planning   |
| Coding              | `glm-4.7`         | Coding-focused, Preserved Thinking      |
| Complex reasoning   | `glm-4.5`         | Hybrid reasoning with deep thinking     |
| General chat        | `glm-4.5-flash`   | Free, good quality                      |
| High throughput     | `glm-4.5-air`     | Compact, fast inference                 |
| Image understanding | `glm-4.6v`        | Best vision model with function calling |
| Embeddings/search   | `embedding-3`     | Latest generation                       |
| Image creation      | `glm-image`       | Latest generation (Jan 2026)            |
| Budget-conscious    | `glm-4.5-flash`   | Free tier available                     |

### Claude Code Model Mapping

When using z.ai's Anthropic-compatible endpoint with Claude Code, map models to slots:

| Claude Code Slot | Recommended GLM Model | Rationale                    |
| ---------------- | --------------------- | ---------------------------- |
| Opus             | `glm-5`               | Most capable, agentic        |
| Sonnet           | `glm-4.7`             | Strong coding, balanced cost |
| Haiku            | `glm-4.5-air`         | Fast, cost-effective         |

## Pricing (per 1M tokens, USD)

| Model            | Input  | Output |
| ---------------- | ------ | ------ |
| `glm-5`          | ~$1.00 | ~$3.20 |
| `glm-4.7`        | $0.60  | $2.20  |
| `glm-4.7-flash`  | Free   | Free   |
| `glm-4.5`        | ~$0.20 | ~$1.10 |
| `glm-4.5-x`      | —      | $8.90  |
| `glm-4.5-flash`  | Free   | Free   |
| `glm-4.6v`       | ~$0.14 | ~$0.41 |
| `glm-4.6v-flash` | Free   | Free   |

_Prices approximate; see [docs.z.ai/guides/overview/pricing](https://docs.z.ai/guides/overview/pricing) for current rates. Batch API available at 50% cost._

## Unique Features

- **MIT license**: GLM-4.5, 4.6, 4.7, and 5 are all open-weight under MIT
- **200K context**: GLM-4.6, 4.7, and 5 support 200K input with up to 128K output
- **Hybrid reasoning**: Toggle deep thinking on/off per request or per turn
- **Tool streaming**: GLM-5 streams output during tool calls for real-time agent UX
- **Free tiers**: `glm-4.5-flash`, `glm-4.7-flash`, `glm-4.6v-flash` are free
- **Domestic chip training**: GLM-5 trained on Huawei Ascend chips, GLM-4.6 on Cambricon — zero NVIDIA dependency
- **Bilingual strength**: Particularly strong in Chinese + English tasks
- **Anthropic-compatible API**: Native Claude Code integration without proxies
- **Native function calling**: OpenAI-style tool description format in all recent models

## References

- [z.ai Developer Docs](https://docs.z.ai/)
- [GLM-5 Overview](https://docs.z.ai/guides/llm/glm-5)
- [GLM-4.7 Docs](https://docs.z.ai/guides/llm/glm-4.7)
- [GLM-4.6 Docs](https://docs.z.ai/guides/llm/glm-4.6)
- [GLM-4.5 Docs](https://docs.z.ai/guides/llm/glm-4.5)
- [Pricing](https://docs.z.ai/guides/overview/pricing)
- [z.ai on GitHub](https://github.com/zai-org)
- [z.ai on Hugging Face](https://huggingface.co/zai-org)
