---
name: cloudflare-images
description: >
  Use this skill when the user asks about Cloudflare Images, image optimization,
  image resizing, image storage and delivery, or managing Images with Pulumi.
---

# Cloudflare Images

Cloudflare Images provides image storage, optimization, and delivery at the edge. It includes on-the-fly resizing, format conversion (WebP/AVIF), and variant-based transformations.

- **Docs**: <https://developers.cloudflare.com/images/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/images>

## Features

- **Storage**: Upload and store images on Cloudflare
- **Transformations**: Resize, crop, blur, rotate via URL parameters
- **Variants**: Pre-defined transformation presets
- **Flexible origin**: Transform images from any origin (no upload needed)
- **Format negotiation**: Auto-serve WebP/AVIF based on browser support

## Image Resizing (via Workers or URL)

Transform images from any origin with URL parameters:

```
https://example.com/cdn-cgi/image/width=300,height=200,fit=crop/path/to/image.jpg
```

Parameters: `width`, `height`, `fit`, `quality`, `format`, `blur`, `rotate`, `sharpen`

## Upload API

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -F "file=@photo.jpg" \
  -F 'metadata={"key":"value"}'
```

## Pulumi IaC

Cloudflare Images is managed via API and dashboard. Pulumi does not have a dedicated Images resource, but you can enable image resizing on a zone:

```typescript
// Image resizing is a zone-level setting
// Managed via Cloudflare dashboard or API
// No dedicated Pulumi resource currently exists
```

## Pricing

| Feature | Cost |
|---------|------|
| Storage | $5.00/100K images/month |
| Delivery | $1.00/100K images served |
| Transformations | Included with delivery |

## References

- [Images Docs](https://developers.cloudflare.com/images/)
- [Image Resizing](https://developers.cloudflare.com/images/transform-images/)
- [Upload API](https://developers.cloudflare.com/images/upload-images/)
