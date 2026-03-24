---
name: cloudflare-tunnels
description: >
  Use this skill when the user asks about Cloudflare Tunnels (formerly Argo
  Tunnel), cloudflared, exposing local services to the internet securely,
  zero-trust ingress, deploying cloudflared via docker-compose, running
  cloudflared in a Proxmox LXC container, or managing Tunnels with Pulumi.
  For docker-compose GitOps deployment patterns, also recall the arcane
  plugin's arcane-gitops skill. For Proxmox LXC host setup, recall the
  proxmox plugin's proxmox-lxc skill.
---

# Cloudflare Tunnels

Cloudflare Tunnels create encrypted, outbound-only connections from your infrastructure to Cloudflare's network. No public IP, open ports, or firewall rules needed — the `cloudflared` daemon runs on your server and reaches out to Cloudflare.

- **Docs**: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/networks/tunnels>
- **CLI**: `cloudflared` (`brew install cloudflared`)
- **Pulumi resources**: `cloudflare.ZeroTrustTunnelCloudflared`, `cloudflare.ZeroTrustTunnelCloudflaredConfig`
- **Docker image**: `cloudflare/cloudflared` ([Docker Hub](https://hub.docker.com/r/cloudflare/cloudflared))

## Architecture

```
Internet → Cloudflare Edge → Tunnel (encrypted) → cloudflared → Your Services
                  ↓
         Access Policies (optional)
         WAF / DDoS Protection
         SSL Termination
```

The tunnel is **outbound-only** — your server connects to Cloudflare, not the other way around. This means:
- No need for a public IP address
- No inbound firewall rules required
- No port forwarding on your router
- Works behind NAT, CGNAT, or corporate firewalls

## Authentication Methods

### Token-based (Recommended for automation)

Create a tunnel in the Cloudflare dashboard or via API, then use the generated token:

```bash
cloudflared tunnel --no-autoupdate run --token <TUNNEL_TOKEN>
```

### Credentials file (Legacy)

```bash
cloudflared tunnel login          # Interactive browser auth
cloudflared tunnel create my-tunnel
cloudflared tunnel run my-tunnel  # Uses ~/.cloudflared/<tunnel-id>.json
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
    originRequest:
      noTLSVerify: true       # Skip TLS verification to origin
      connectTimeout: 30s
  - hostname: ssh.example.com
    service: ssh://localhost:22
  - hostname: rdp.example.com
    service: rdp://localhost:3389
  - service: http_status:404    # Catch-all (REQUIRED — must be last)
```

### Ingress Service Types

| Protocol | Example | Use Case |
|----------|---------|----------|
| `http://host:port` | Web apps, APIs | Most common |
| `https://host:port` | TLS-terminated origins | When origin has its own cert |
| `ssh://host:port` | SSH access | Remote shell via browser |
| `rdp://host:port` | Remote Desktop | Windows RDP via browser |
| `tcp://host:port` | Raw TCP | Databases, custom protocols |
| `unix:/path/to/socket` | Unix sockets | Docker socket, etc. |
| `http_status:404` | Static response | Catch-all fallback |

## Docker Compose Deployment

### Basic Setup

```yaml
# docker-compose.yaml
name: cloudflared

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: always
    command: tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}
    networks:
      - cloudflared

networks:
  cloudflared:
    driver: bridge
    name: cloudflared
```

### Production Setup with 1Password Secrets

For production deployments, avoid putting tokens in environment variables. Use an init container to fetch secrets from a secrets manager:

```yaml
# docker-compose.yaml
name: cloudflared

services:
  init-secrets:
    image: 1password/op:2
    user: "0:0"
    environment:
      - OP_SERVICE_ACCOUNT_TOKEN=${OP_SERVICE_ACCOUNT_TOKEN}
    volumes:
      - cloudflare-secrets:/run/secrets:rw
    command: |
      /bin/bash -c
      fetch "op://Infrastructure/cloudflared/token" "/run/secrets/cloudflared_token"
      chmod 444 /run/secrets/*

  cloudflared:
    image: cloudflare/cloudflared:2026.3.0  # Pin version for reproducibility
    restart: always
    command: tunnel --no-autoupdate run --token-file /run/secrets/cloudflared_token
    volumes:
      - cloudflare-secrets:/run/secrets:ro
    depends_on:
      init-secrets:
        condition: service_completed_successfully
    networks:
      - cloudflared

volumes:
  cloudflare-secrets:
    driver: local

networks:
  cloudflared:
    driver: bridge
    name: cloudflared
```

### Connecting Other Services

Other docker-compose stacks join the `cloudflared` network to be reachable via the tunnel:

```yaml
# In another stack's docker-compose.yaml
services:
  my-app:
    image: my-app:latest
    networks:
      - cloudflared

networks:
  cloudflared:
    external: true  # Join the network created by the cloudflared stack
```

Then add the hostname → service mapping in the Cloudflare dashboard (or via Pulumi/API).

### GitOps with Arcane

If using Arcane for GitOps deployment of docker-compose stacks, place the cloudflared compose file in your iac repo at `hosts/<hostname>/cloudflared/docker-compose.yaml`. Arcane will sync and deploy it automatically on push to main. See the **arcane** plugin's `arcane-gitops` skill for the full GitOps workflow.

Directory structure:

```
iac/
  hosts/
    my-server/
      cloudflared/
        docker-compose.yaml
      my-app/
        docker-compose.yaml   # Joins cloudflared network
```

## Proxmox LXC Deployment

For running `cloudflared` in a Proxmox LXC container (lightweight alternative to a full VM):

### Option 1: Direct Install in LXC

```bash
# On the Proxmox host, create an unprivileged LXC container
pct create 200 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname cloudflared \
  --memory 512 \
  --cores 1 \
  --rootfs local-lvm:4 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1

pct start 200

# Inside the LXC container
pct enter 200
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bookworm main" \
  | tee /etc/apt/sources.list.d/cloudflared.list
apt update && apt install -y cloudflared

# Run as a service
cloudflared service install <TUNNEL_TOKEN>
systemctl enable --now cloudflared
```

### Option 2: Docker in LXC (for docker-compose stacks)

For running docker-compose stacks (including cloudflared) in an LXC container, you need a **privileged container with nesting enabled**. See the **proxmox** plugin's `proxmox-lxc` skill for detailed setup instructions.

```bash
# Create privileged LXC with nesting for Docker support
pct create 201 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname docker-host \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1 \
  --unprivileged 0

pct start 201

# Inside the LXC, install Docker
pct enter 201
curl -fsSL https://get.docker.com | sh

# Then deploy cloudflared via docker-compose as shown above
```

## Pulumi IaC

### Create a Tunnel

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as cloudflare from "@pulumi/cloudflare";

const config = new pulumi.Config();
const cfConfig = new pulumi.Config("cloudflare");
const accountId = cfConfig.require("accountId");

// Generate a tunnel secret (32+ bytes, base64-encoded)
const tunnelSecret = config.requireSecret("tunnelSecret");

const tunnel = new cloudflare.ZeroTrustTunnelCloudflared("my-tunnel", {
  accountId,
  name: "my-tunnel",
  secret: tunnelSecret,
});

// Export the token for use with cloudflared
export const tunnelToken = tunnel.tunnelToken;
```

### Configure Ingress Rules

```typescript
const tunnelConfig = new cloudflare.ZeroTrustTunnelCloudflaredConfig("my-tunnel-config", {
  accountId,
  tunnelId: tunnel.id,
  config: {
    ingressRules: [
      {
        hostname: "app.example.com",
        service: "http://my-app:8080",
      },
      {
        hostname: "api.example.com",
        service: "http://my-api:3000",
        originRequest: {
          connectTimeout: "30s",
          noTlsVerify: true,
        },
      },
      {
        // Catch-all (required, must be last)
        service: "http_status:404",
      },
    ],
  },
});
```

### DNS Records for Tunnel

```typescript
const zone = cloudflare.getZoneOutput({ name: "example.com", accountId });

const appDns = new cloudflare.Record("app-dns", {
  zoneId: zone.id,
  name: "app",
  type: "CNAME",
  content: pulumi.interpolate`${tunnel.id}.cfargotunnel.com`,
  proxied: true,
});

const apiDns = new cloudflare.Record("api-dns", {
  zoneId: zone.id,
  name: "api",
  type: "CNAME",
  content: pulumi.interpolate`${tunnel.id}.cfargotunnel.com`,
  proxied: true,
});
```

### Combine with Access Policies

Protect tunnel-exposed services with Zero Trust Access (see the `cloudflare-zero-trust` skill):

```typescript
const accessApp = new cloudflare.ZeroTrustAccessApplication("app-access", {
  zoneId: zone.id,
  name: "Internal App",
  domain: "app.example.com",
  type: "self_hosted",
  sessionDuration: "24h",
});

const accessPolicy = new cloudflare.ZeroTrustAccessPolicy("allow-team", {
  applicationId: accessApp.id,
  zoneId: zone.id,
  name: "Allow Team",
  precedence: 1,
  decision: "allow",
  includes: [{
    emails: ["admin@example.com"],
  }],
});
```

## Monitoring

```bash
# Check tunnel status
cloudflared tunnel info my-tunnel

# View tunnel metrics (Prometheus format)
cloudflared tunnel --metrics localhost:2000

# Dashboard: see active connections, latency, errors
# https://dash.cloudflare.com/?to=/:account/networks/tunnels
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Tunnel won't connect | Check `TUNNEL_TOKEN` / credentials file. Verify DNS resolves |
| `ERR_CONNECTION_REFUSED` | Origin service isn't running or wrong port |
| Intermittent 502s | Increase `connectTimeout` in ingress config |
| Can't reach service from tunnel | Ensure both containers are on the same Docker network |
| Token file permission denied | Check volume mount permissions (`:ro` vs `:rw`) |
| LXC DNS issues | Add `--nameserver 1.1.1.1` to LXC config |

## References

- [Tunnels Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Create a Tunnel (Dashboard)](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/)
- [Tunnel Configuration](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/remote-management/)
- [Ingress Rules](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/origin-configuration/)
- [cloudflared Downloads](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)
- [Docker Hub: cloudflare/cloudflared](https://hub.docker.com/r/cloudflare/cloudflared)
- [Pulumi ZeroTrustTunnelCloudflared](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zerotrusttunnelcloudflared/)
- [Pulumi ZeroTrustTunnelCloudflaredConfig](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zerotrusttunnelcloudflaredconfig/)
