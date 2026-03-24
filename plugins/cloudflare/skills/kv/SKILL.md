---
name: cloudflare-kv
description: >
  Use this skill when the user asks about Cloudflare Workers KV, key-value
  storage on Cloudflare's edge, distributed KV stores, or managing KV
  namespaces with Pulumi.
---

# Cloudflare Workers KV

Workers KV is a global, low-latency key-value data store. It's eventually consistent with reads served from the nearest edge location.

- **Docs**: <https://developers.cloudflare.com/kv/>
- **Pulumi resource**: `cloudflare.WorkersKvNamespace` ([docs](https://www.pulumi.com/registry/packages/cloudflare/api-docs/workerskvnamespace/))

## Usage from Workers

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    await env.MY_KV.put("key", "value", { expirationTtl: 3600 });
    const value = await env.MY_KV.get("key");
    return new Response(value);
  },
};
```

### Wrangler Config

```toml
[[kv_namespaces]]
binding = "MY_KV"
id = "xxxx"
```

## Key Characteristics

- **Eventually consistent** — writes propagate globally within ~60 seconds
- **Read-heavy workloads** — optimized for high read:write ratio
- **Max value size**: 25 MB
- **Max key size**: 512 bytes
- **Metadata**: up to 1 KB per key

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const kv = new cloudflare.WorkersKvNamespace("my-kv", {
  accountId,
  title: "my-kv-namespace",
});

export const kvNamespaceId = kv.id;
```

## Pricing

| Resource | Free | Paid |
|----------|------|------|
| Reads | 100K/day | $0.50/M |
| Writes | 1K/day | $5.00/M |
| Deletes | 1K/day | $5.00/M |
| Lists | 1K/day | $5.00/M |
| Storage | 1 GB | $0.50/GB/month |

## References

- [KV Docs](https://developers.cloudflare.com/kv/)
- [KV API](https://developers.cloudflare.com/kv/api/)
- [Pulumi WorkersKvNamespace](https://www.pulumi.com/registry/packages/cloudflare/api-docs/workerskvnamespace/)
