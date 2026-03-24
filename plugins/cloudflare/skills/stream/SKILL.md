---
name: cloudflare-stream
description: >
  Use this skill when the user asks about Cloudflare Stream, video hosting
  and streaming, video encoding, live streaming, or managing Stream with Pulumi.
---

# Cloudflare Stream

Stream is Cloudflare's video hosting and delivery platform. Upload, encode, and stream video with adaptive bitrate, built-in player, and live streaming support.

- **Docs**: <https://developers.cloudflare.com/stream/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/stream>

## Features

- **On-demand video**: Upload, encode, and deliver video
- **Live streaming**: RTMPS/SRT/WebRTC input with HLS/DASH output
- **Adaptive bitrate**: Automatic multi-quality encoding
- **Embed player**: Built-in video player with controls
- **Signed URLs**: Token-based access control
- **Captions**: SRT/VTT caption upload
- **Clips**: Create sub-clips from existing videos
- **Analytics**: Views, watch time, quality metrics

## Upload

```bash
# Direct upload via API
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{account_id}/stream" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -F "file=@video.mp4"

# Upload via URL
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/copy" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -d '{"url": "https://example.com/video.mp4"}'
```

## Embed

```html
<iframe
  src="https://customer-{CODE}.cloudflarestream.com/{VIDEO_ID}/iframe"
  allow="accelerometer; gyroscope; autoplay; encrypted-media; picture-in-picture"
  allowfullscreen
></iframe>
```

## Pulumi IaC

Stream is managed via API and dashboard. No dedicated Pulumi resource exists for Stream videos, but live inputs can be managed:

```typescript
// Stream live inputs and video management are done via the Cloudflare API
// No dedicated Pulumi resources currently exist
```

## Pricing

| Resource | Cost |
|----------|------|
| Storage | $5.00/1,000 min/month |
| Delivery | $1.00/1,000 min viewed |
| Live input | $0.75/1,000 min ingested |

## References

- [Stream Docs](https://developers.cloudflare.com/stream/)
- [Upload Videos](https://developers.cloudflare.com/stream/uploading-videos/)
- [Live Streaming](https://developers.cloudflare.com/stream/stream-live/)
- [Player API](https://developers.cloudflare.com/stream/viewing-videos/using-the-stream-player/)
