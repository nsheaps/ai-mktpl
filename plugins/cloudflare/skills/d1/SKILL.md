---
name: cloudflare-d1
description: >
  Use this skill when the user asks about Cloudflare D1, serverless SQL
  databases on Cloudflare, SQLite on the edge, or managing D1 databases
  with Pulumi.
---

# Cloudflare D1

D1 is Cloudflare's serverless SQLite database. It runs on Cloudflare's edge with automatic read replication, point-in-time recovery, and native Worker bindings.

- **Docs**: <https://developers.cloudflare.com/d1/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/d1>
- **Pulumi resource**: `cloudflare.D1Database` ([docs](https://www.pulumi.com/registry/packages/cloudflare/api-docs/d1database/))

## Usage from Workers

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { results } = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(1).all();
    return Response.json(results);
  },
};
```

### Wrangler Config

```toml
[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "xxxx-xxxx-xxxx"
```

## CLI Operations

```bash
# Create a database
npx wrangler d1 create my-database

# Run SQL
npx wrangler d1 execute my-database --command "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"

# Run migrations
npx wrangler d1 migrations apply my-database
```

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const db = new cloudflare.D1Database("my-database", {
  accountId,
  name: "my-database",
});

export const databaseId = db.id;
```

## Pricing

| Resource     | Free     | Paid           |
| ------------ | -------- | -------------- |
| Rows read    | 5M/day   | $0.001/M       |
| Rows written | 100K/day | $1.00/M        |
| Storage      | 5 GB     | $0.75/GB/month |

## References

- [D1 Docs](https://developers.cloudflare.com/d1/)
- [Query API](https://developers.cloudflare.com/d1/worker-api/)
- [Migrations](https://developers.cloudflare.com/d1/reference/migrations/)
- [Pulumi D1Database](https://www.pulumi.com/registry/packages/cloudflare/api-docs/d1database/)
