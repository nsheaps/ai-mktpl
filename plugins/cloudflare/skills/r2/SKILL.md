---
name: cloudflare-r2
description: >
  Use this skill when the user asks about Cloudflare R2, S3-compatible object
  storage, storing files/blobs on Cloudflare, zero-egress storage, or managing
  R2 buckets with Pulumi.
---

# Cloudflare R2

R2 is Cloudflare's S3-compatible object storage with **zero egress fees**. It supports the S3 API, Workers bindings, and public bucket access.

- **Docs**: <https://developers.cloudflare.com/r2/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/r2>
- **Pulumi resource**: `cloudflare.R2Bucket` ([docs](https://www.pulumi.com/registry/packages/cloudflare/api-docs/r2bucket/))

## Key Features

- **S3-compatible API** — use existing S3 SDKs and tools
- **Zero egress fees** — no charges for data leaving R2
- **Worker bindings** — access from Workers without HTTP overhead
- **Public buckets** — serve objects directly via custom domain
- **Lifecycle rules** — auto-expire or transition objects

## Usage from Workers

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Write
    await env.MY_BUCKET.put("key", "value");
    // Read
    const obj = await env.MY_BUCKET.get("key");
    return new Response(obj?.body);
  },
};
```

## S3 API Access

```bash
# Configure AWS CLI for R2
aws configure set default.s3.endpoint_url "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
aws configure set default.s3.region auto

# Use R2 API tokens for credentials
aws s3 ls s3://my-bucket/
```

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const bucket = new cloudflare.R2Bucket("my-bucket", {
  accountId,
  name: "my-bucket",
  location: "WNAM", // Optional: WNAM, ENAM, WEUR, EEUR, APAC
});

export const bucketName = bucket.name;
```

## Pricing

| Resource            | Free        | Paid             |
| ------------------- | ----------- | ---------------- |
| Storage             | 10 GB/month | $0.015/GB/month  |
| Class A ops (write) | 1M/month    | $4.50/M          |
| Class B ops (read)  | 10M/month   | $0.36/M          |
| Egress              | Unlimited   | $0 (always free) |

## References

- [R2 Docs](https://developers.cloudflare.com/r2/)
- [S3 API Compatibility](https://developers.cloudflare.com/r2/api/s3/)
- [Worker Bindings](https://developers.cloudflare.com/r2/api/workers/)
- [Pulumi R2Bucket](https://www.pulumi.com/registry/packages/cloudflare/api-docs/r2bucket/)
