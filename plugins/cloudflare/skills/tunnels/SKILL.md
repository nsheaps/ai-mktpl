---
name: cloudflare-tunnels
description: >
  Use this skill when the user asks about Cloudflare Tunnels (formerly Argo
  Tunnel), cloudflared, exposing local services to the internet securely,
  zero-trust ingress, or managing Tunnels with Pulumi.
---

# Cloudflare Tunnels

Cloudflare Tunnels create encrypted, outbound-only connections from your infrastructure to Cloudflare's network. No public IP or firewall rules needed — the `cloudflared` daemon runs on your server and reaches out to Cloudflare.

- **Docs**: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/networks/tunnels>
- **CLI**: `cloudflared` (`brew install cloudflared`)
- **Pulumi resources**: `cloudflare.ZeroTrustTunnelCloudflared`, `cloudflare.ZeroTrustTunnelCloudflaredConfig`

## Quick Start

```bash
# Authenticate
cloudflared tunnel login

# Create a tunnel
cloudflared tunnel create my-tunnel

# Route DNS
cloudflared tunnel route dns my-tunnel app.example.com

# Run the tunnel
cloudflared tunnel run my-tunnel
```

## Configuration File

```yaml
# ~/.cloudflared/config.yml
tunnel: <TUNNEL_UUID>
credentials-file: /path/to/credentials.json

ingress:
  - hostname: app.example.com
    service: http://localhost:8080
  - hostname: api.example.com
    service: http://localhost:3000
  - service: http_status:404  # Catch-all (required)
```

## Docker Deployment

```yaml
# docker-compose.yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}
    restart: unless-stopped
```

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const tunnel = new cloudflare.ZeroTrustTunnelCloudflared("my-tunnel", {
  accountId,
  name: "my-tunnel",
  secret: tunnelSecret,  // Base64-encoded 32+ byte random string
});

const tunnelConfig = new cloudflare.ZeroTrustTunnelCloudflaredConfig("my-tunnel-config", {
  accountId,
  tunnelId: tunnel.id,
  config: {
    ingressRules: [
      {
        hostname: "app.example.com",
        service: "http://localhost:8080",
      },
      {
        service: "http_status:404",
      },
    ],
  },
});

// DNS record pointing to the tunnel
const tunnelDns = new cloudflare.Record("tunnel-dns", {
  zoneId: zone.id,
  name: "app",
  type: "CNAME",
  content: pulumi.interpolate`${tunnel.id}.cfargotunnel.com`,
  proxied: true,
});

export const tunnelToken = tunnel.tunnelToken;
```

## References

- [Tunnels Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Configuration](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/)
- [cloudflared CLI](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)
- [Pulumi ZeroTrustTunnelCloudflared](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zerotrusttunnelcloudflared/)
