---
name: glm-models
description: >
  Use this skill when the user asks about GLM models, GLM-4, GLM-4-Plus,
  GLM-4V, ChatGLM, CogView, CogVideoX, Zhipu AI model capabilities,
  model selection for different tasks, or comparing GLM models.
---

# GLM Model Family

The GLM (General Language Model) family is developed by Zhipu AI (智谱AI) and available via [z.ai](https://z.ai/). These models support text generation, vision, code, embeddings, image generation, and video generation.

- **Model List**: <https://open.bigmodel.cn/dev/api/normal-model/glm-4>
- **API Base URL**: `https://open.bigmodel.cn/api/paas/v4/`

## Text Generation Models

| Model | Context | Description | Best For |
|-------|---------|-------------|----------|
| `glm-4-plus` | 128K | Most capable GLM-4 variant; strong reasoning and instruction following | Complex tasks, analysis, creative writing |
| `glm-4-0520` | 128K | Specific snapshot of GLM-4 | Reproducible results |
| `glm-4-air` | 128K | Fast, cost-effective variant | High-throughput applications |
| `glm-4-airx` | 8K | Ultra-fast inference | Real-time chat, low-latency |
| `glm-4-long` | 1M | Million-token context window | Very long documents, large codebases |
| `glm-4-flash` | 128K | Free tier model; good quality for basic tasks | Prototyping, low-cost applications |
| `glm-4-flashx` | 128K | Enhanced flash with better performance | Better quality at low cost |

## Vision Models

| Model | Context | Description |
|-------|---------|-------------|
| `glm-4v` | 2K | Multimodal: text + image understanding |
| `glm-4v-plus` | 8K | Enhanced vision with longer context |
| `glm-4v-flash` | 8K | Fast vision model (free tier) |

### Vision API Example

```bash
curl "https://open.bigmodel.cn/api/paas/v4/chat/completions" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4v-plus",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "What is in this image?"},
        {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}}
      ]
    }]
  }'
```

## Embedding Models

| Model | Dimensions | Description |
|-------|-----------|-------------|
| `embedding-3` | 2048 | General-purpose text embeddings |
| `embedding-2` | 1024 | Previous generation embeddings |

### Embedding API Example

```bash
curl "https://open.bigmodel.cn/api/paas/v4/embeddings" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "embedding-3",
    "input": "What is machine learning?"
  }'
```

## Image Generation Models

| Model | Description |
|-------|-------------|
| `cogview-3-plus` | High-quality text-to-image generation |
| `cogview-3` | Standard text-to-image |
| `cogview-3-flash` | Fast image generation |

### Image Generation Example

```bash
curl "https://open.bigmodel.cn/api/paas/v4/images/generations" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "cogview-3-plus",
    "prompt": "A futuristic city at sunset, cyberpunk style"
  }'
```

## Video Generation Models

| Model | Description |
|-------|-------------|
| `cogvideox` | Text-to-video generation |
| `cogvideox-flash` | Fast video generation |

## Code Generation

GLM-4 models (especially `glm-4-plus` and `glm-4-air`) are strong at code generation. They support:

- Multiple programming languages (Python, JavaScript, TypeScript, Go, Rust, Java, etc.)
- Code explanation and review
- Bug fixing and refactoring
- Unit test generation

## Model Selection Guide

| Use Case | Recommended Model | Why |
|----------|-------------------|-----|
| General chat | `glm-4-flash` | Free, good quality |
| Complex reasoning | `glm-4-plus` | Most capable |
| High throughput | `glm-4-airx` | Fastest inference |
| Long documents | `glm-4-long` | 1M context window |
| Image understanding | `glm-4v-plus` | Best vision model |
| Embeddings/search | `embedding-3` | Latest generation |
| Image creation | `cogview-3-plus` | Highest quality |
| Budget-conscious | `glm-4-flash` | Free tier available |

## Pricing

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| glm-4-plus | ¥50 (~$7) | ¥50 (~$7) |
| glm-4-air | ¥1 (~$0.14) | ¥1 (~$0.14) |
| glm-4-airx | ¥10 (~$1.40) | ¥10 (~$1.40) |
| glm-4-long | ¥1 (~$0.14) | ¥1 (~$0.14) |
| glm-4-flash | Free | Free |
| glm-4-flashx | ¥0.1 (~$0.014) | ¥0.1 (~$0.014) |

*Prices in CNY; USD approximate at ~¥7.2/$ rate.*

## Unique Features

- **1M token context** (`glm-4-long`): One of the longest context windows available
- **Free tier** (`glm-4-flash`, `glm-4v-flash`): Production-quality models at zero cost
- **Video generation** (`cogvideox`): Text-to-video capabilities
- **OpenAI-compatible API**: Drop-in replacement for OpenAI SDK usage
- **Bilingual strength**: Particularly strong in Chinese + English tasks

## References

- [GLM-4 Model Docs](https://open.bigmodel.cn/dev/api/normal-model/glm-4)
- [Vision Models](https://open.bigmodel.cn/dev/api/normal-model/glm-4v)
- [Embedding Models](https://open.bigmodel.cn/dev/api/vector/embedding-3)
- [Image Generation](https://open.bigmodel.cn/dev/api/cogview/cogview-3-plus)
- [Video Generation](https://open.bigmodel.cn/dev/api/videomodel/cogvideox)
- [Pricing](https://open.bigmodel.cn/pricing)
