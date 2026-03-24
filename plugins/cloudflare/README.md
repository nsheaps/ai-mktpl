# Cloudflare Developer Platform Plugin

Skills for managing Cloudflare developer platform components, including setup guidance and Pulumi infrastructure-as-code examples for each service.

## Skills

| Skill                        | Component                                                                                 | Description                                                                                                                                           |
| ---------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cloudflare-ai-gateway`      | [AI Gateway](https://developers.cloudflare.com/ai-gateway/)                               | Proxy AI API requests through Cloudflare for logging, caching, rate limiting, and cost tracking. Includes Claude Code setup via `ANTHROPIC_BASE_URL`. |
| `cloudflare-workers`         | [Workers](https://developers.cloudflare.com/workers/)                                     | Serverless JavaScript/TypeScript on Cloudflare's edge network                                                                                         |
| `cloudflare-workers-ai`      | [Workers AI](https://developers.cloudflare.com/workers-ai/)                               | Run open-source AI models on Cloudflare's GPU edge                                                                                                    |
| `cloudflare-r2`              | [R2](https://developers.cloudflare.com/r2/)                                               | S3-compatible object storage with zero egress fees                                                                                                    |
| `cloudflare-d1`              | [D1](https://developers.cloudflare.com/d1/)                                               | Serverless SQLite database                                                                                                                            |
| `cloudflare-kv`              | [KV](https://developers.cloudflare.com/kv/)                                               | Global key-value storage                                                                                                                              |
| `cloudflare-queues`          | [Queues](https://developers.cloudflare.com/queues/)                                       | Message queues for Workers                                                                                                                            |
| `cloudflare-durable-objects` | [Durable Objects](https://developers.cloudflare.com/durable-objects/)                     | Stateful serverless with strong consistency                                                                                                           |
| `cloudflare-pages`           | [Pages](https://developers.cloudflare.com/pages/)                                         | Full-stack web hosting with Git integration                                                                                                           |
| `cloudflare-tunnels`         | [Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Secure outbound-only connections to your infrastructure                                                                                               |
| `cloudflare-zero-trust`      | [Zero Trust](https://developers.cloudflare.com/cloudflare-one/)                           | Identity-based access control replacing VPNs                                                                                                          |
| `cloudflare-dns`             | [DNS](https://developers.cloudflare.com/dns/)                                             | Authoritative DNS with proxy and DNSSEC                                                                                                               |
| `cloudflare-images`          | [Images](https://developers.cloudflare.com/images/)                                       | Image storage, optimization, and delivery                                                                                                             |
| `cloudflare-stream`          | [Stream](https://developers.cloudflare.com/stream/)                                       | Video hosting and live streaming                                                                                                                      |
| `cloudflare-vectorize`       | [Vectorize](https://developers.cloudflare.com/vectorize/)                                 | Vector database for semantic search and RAG                                                                                                           |

## Highlights

### AI Gateway + Claude Code

The `cloudflare-ai-gateway` skill provides detailed instructions for routing Claude Code (CLI and web) through Cloudflare AI Gateway via `ANTHROPIC_BASE_URL`, including:

- Local CLI setup with environment variables
- Claude Code web setup via SessionStart hooks
- Routing to OpenRouter and z.ai through the gateway
- Fallback chains across providers
- Pulumi IaC for the gateway resource

### Pulumi IaC

Each skill includes Pulumi TypeScript examples using `@pulumi/cloudflare`. See the [nsheaps/iac](https://github.com/nsheaps/iac) repository for a production example.
