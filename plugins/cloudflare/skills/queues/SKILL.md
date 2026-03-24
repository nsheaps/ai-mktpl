---
name: cloudflare-queues
description: >
  Use this skill when the user asks about Cloudflare Queues, message queues
  on Cloudflare, asynchronous processing with Workers, or managing Queues
  with Pulumi.
---

# Cloudflare Queues

Queues enable Workers to send and receive messages for asynchronous processing. Built for reliable, at-least-once delivery with automatic batching and retries.

- **Docs**: <https://developers.cloudflare.com/queues/>
- **Pulumi resource**: `cloudflare.Queue` ([docs](https://www.pulumi.com/registry/packages/cloudflare/api-docs/queue/))

## Producer (send messages)

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    await env.MY_QUEUE.send({ url: request.url, timestamp: Date.now() });
    return new Response("Queued!");
  },
};
```

## Consumer (receive messages)

```typescript
export default {
  async queue(batch: MessageBatch<any>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      console.log(message.body);
      message.ack();
    }
  },
};
```

### Wrangler Config

```toml
[[queues.producers]]
queue = "my-queue"
binding = "MY_QUEUE"

[[queues.consumers]]
queue = "my-queue"
max_batch_size = 10
max_batch_timeout = 30
```

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const queue = new cloudflare.Queue("my-queue", {
  accountId,
  name: "my-queue",
});

export const queueId = queue.id;
```

## Pricing

| Resource | Free | Paid |
|----------|------|------|
| Messages | 1M/month | $0.40/M |
| Operations | Included | Included |
| Storage (backlog) | — | $0.025/GB |

## References

- [Queues Docs](https://developers.cloudflare.com/queues/)
- [Producer API](https://developers.cloudflare.com/queues/configuration/javascript-apis/#producer)
- [Consumer API](https://developers.cloudflare.com/queues/configuration/javascript-apis/#consumer)
- [Pulumi Queue](https://www.pulumi.com/registry/packages/cloudflare/api-docs/queue/)
