---
name: cloudflare-durable-objects
description: >
  Use this skill when the user asks about Cloudflare Durable Objects, stateful
  serverless on Cloudflare, WebSocket coordination, distributed counters or
  locks, or managing Durable Objects with Pulumi.
---

# Cloudflare Durable Objects

Durable Objects provide strongly consistent, low-latency coordination and state for Workers. Each object is a single-threaded instance with persistent storage, ideal for WebSocket servers, counters, rate limiters, and collaborative apps.

- **Docs**: <https://developers.cloudflare.com/durable-objects/>
- **Pulumi**: Deployed as part of `cloudflare.WorkersScript` with `durableObjectBindings`

## Durable Object Class

```typescript
export class Counter {
  state: DurableObjectState;

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    let value = (await this.state.storage.get<number>("count")) ?? 0;
    value++;
    await this.state.storage.put("count", value);
    return new Response(value.toString());
  }
}
```

## Accessing from a Worker

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const id = env.COUNTER.idFromName("my-counter");
    const stub = env.COUNTER.get(id);
    return stub.fetch(request);
  },
};
```

### Wrangler Config

```toml
[durable_objects]
bindings = [
  { name = "COUNTER", class_name = "Counter" }
]

[[migrations]]
tag = "v1"
new_classes = ["Counter"]
```

## Key Properties

- **Single-threaded**: Only one instance per ID exists globally
- **Strongly consistent**: All reads/writes to the same object are serialized
- **Persistent storage**: Key-value storage survives restarts (SQLite-backed)
- **WebSocket support**: Built-in WebSocket hibernation API
- **Alarms**: Schedule future wake-ups

## Pulumi IaC

```typescript
const worker = new cloudflare.WorkersScript("do-worker", {
  accountId,
  name: "do-worker",
  content: workerScript,
  module: true,
});

// Durable Object bindings are part of the Worker script resource.
// The class must be exported from the Worker module.
// Migrations are handled via wrangler.toml, not Pulumi.
```

## Pricing

| Resource       | Free        | Paid           |
| -------------- | ----------- | -------------- |
| Requests       | 1M included | $0.15/M        |
| Duration       | 400K GB-s   | $12.50/M GB-s  |
| Storage reads  | 1M/month    | $0.20/M        |
| Storage writes | 1M/month    | $1.00/M        |
| Storage        | 1 GB        | $0.20/GB/month |

## References

- [Durable Objects Docs](https://developers.cloudflare.com/durable-objects/)
- [Storage API](https://developers.cloudflare.com/durable-objects/api/storage-api/)
- [WebSockets](https://developers.cloudflare.com/durable-objects/api/websockets/)
- [Alarms](https://developers.cloudflare.com/durable-objects/api/alarms/)
