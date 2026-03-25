---
name: cloudflare-vectorize
description: >
  Use this skill when the user asks about Cloudflare Vectorize, vector
  databases on Cloudflare, semantic search, RAG pipelines, embedding storage,
  or managing Vectorize with Pulumi.
---

# Cloudflare Vectorize

Vectorize is Cloudflare's vector database for building semantic search, recommendation engines, and RAG (Retrieval-Augmented Generation) applications. It integrates natively with Workers AI for embedding generation.

- **Docs**: <https://developers.cloudflare.com/vectorize/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/vectorize>

## Usage from Workers

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Generate embeddings with Workers AI
    const embedding = await env.AI.run("@cf/baai/bge-base-en-v1.5", {
      text: ["What is Cloudflare?"],
    });

    // Insert into Vectorize
    await env.VECTORIZE.upsert([
      {
        id: "doc-1",
        values: embedding.data[0],
        metadata: { title: "About Cloudflare" },
      },
    ]);

    // Query
    const results = await env.VECTORIZE.query(embedding.data[0], {
      topK: 5,
      returnMetadata: "all",
    });

    return Response.json(results);
  },
};
```

### Wrangler Config

```toml
[[vectorize]]
binding = "VECTORIZE"
index_name = "my-index"
```

## CLI Operations

```bash
# Create an index
npx wrangler vectorize create my-index --dimensions 768 --metric cosine

# Insert vectors
npx wrangler vectorize insert my-index --file vectors.ndjson
```

## Pulumi IaC

```typescript
// Vectorize indexes are managed via wrangler CLI
// No dedicated Pulumi resource currently exists
// Use Pulumi's Command provider if automation is needed:

import * as command from "@pulumi/command";

const vectorizeIndex = new command.local.Command("vectorize-index", {
  create: "npx wrangler vectorize create my-index --dimensions 768 --metric cosine",
  delete: "npx wrangler vectorize delete my-index",
});
```

## Index Configuration

| Setting    | Options                              | Description                            |
| ---------- | ------------------------------------ | -------------------------------------- |
| Dimensions | 1–1536                               | Must match your embedding model output |
| Metric     | `cosine`, `euclidean`, `dot-product` | Similarity metric                      |

## Pricing

| Resource           | Free      | Paid          |
| ------------------ | --------- | ------------- |
| Queried dimensions | 30M/month | $0.01/M       |
| Stored dimensions  | 5M        | $0.05/M/month |
| Indexes            | 5         | 100           |

## References

- [Vectorize Docs](https://developers.cloudflare.com/vectorize/)
- [Worker API](https://developers.cloudflare.com/vectorize/reference/client-api/)
- [Wrangler Commands](https://developers.cloudflare.com/vectorize/reference/wrangler-commands/)
