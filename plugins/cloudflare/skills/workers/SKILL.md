---
name: cloudflare-workers
description: >
  Use this skill when the user asks about Cloudflare Workers, deploying
  serverless functions on Cloudflare's edge network, writing Worker scripts,
  configuring Worker routes and bindings, or managing Workers with Pulumi.
---

# Cloudflare Workers

Cloudflare Workers let you run JavaScript/TypeScript (or WASM) on Cloudflare's global edge network with near-zero cold starts. Workers execute in V8 isolates, not containers.

- **Docs**: <https://developers.cloudflare.com/workers/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/workers>
- **CLI**: `wrangler` (`npx wrangler` or `npm i -g wrangler`)
- **Pulumi resource**: `cloudflare.WorkersScript` ([docs](https://www.pulumi.com/registry/packages/cloudflare/api-docs/workersscript/))

## Quick Start

```bash
# Create a new Worker project
npx wrangler init my-worker
cd my-worker

# Develop locally
npx wrangler dev

# Deploy
npx wrangler deploy
```

## Worker Script Structure (ES Modules)

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return new Response("Hello from the edge!");
  },

  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    // Cron trigger handler
  },
};

interface Env {
  MY_KV: KVNamespace;
  MY_R2: R2Bucket;
  MY_DB: D1Database;
  SECRET_KEY: string;
}
```

## Key Bindings

Workers connect to other Cloudflare services via **bindings** declared in `wrangler.toml`:

| Binding | Type | Use Case |
|---------|------|----------|
| KV | `kv_namespaces` | Key-value storage |
| R2 | `r2_buckets` | Object storage |
| D1 | `d1_databases` | SQL database |
| Durable Objects | `durable_objects` | Stateful coordination |
| Queues | `queues` | Message queues |
| AI | `ai` | Workers AI inference |
| Service | `services` | Worker-to-Worker calls |
| Secret | `[vars]` / secrets | Environment variables |

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const worker = new cloudflare.WorkersScript("my-worker", {
  accountId: accountId,
  name: "my-worker",
  content: workerScriptContent,  // The JS/TS bundle as a string
  module: true,                   // ES modules format

  // Bindings
  kvNamespaceBindings: [{
    name: "MY_KV",
    namespaceId: myKvNamespace.id,
  }],
  r2BucketBindings: [{
    name: "MY_R2",
    bucketName: myR2Bucket.name,
  }],
  d1DatabaseBindings: [{
    name: "MY_DB",
    databaseId: myD1Database.id,
  }],
  plainTextBindings: [{
    name: "ENV_VAR",
    text: "value",
  }],
  secretTextBindings: [{
    name: "API_KEY",
    text: config.requireSecret("apiKey"),
  }],
});

// Route the worker to a custom domain
const route = new cloudflare.WorkersRoute("my-route", {
  zoneId: zone.id,
  pattern: "api.example.com/*",
  scriptName: worker.name,
});
```

## Limits

| Limit | Free | Paid |
|-------|------|------|
| Requests/day | 100,000 | Unlimited |
| CPU time/request | 10ms | 30s |
| Script size | 1 MB | 10 MB |
| Subrequests | 50 | 1,000 |
| KV reads/request | 1,000 | 1,000 |

## References

- [Workers Docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Runtime APIs](https://developers.cloudflare.com/workers/runtime-apis/)
- [Bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/)
- [Pulumi WorkersScript](https://www.pulumi.com/registry/packages/cloudflare/api-docs/workersscript/)
