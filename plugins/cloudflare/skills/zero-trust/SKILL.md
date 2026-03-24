---
name: cloudflare-zero-trust
description: >
  Use this skill when the user asks about Cloudflare Zero Trust, Access
  policies, identity-based access control, protecting self-hosted apps,
  WARP client, Gateway DNS filtering, device posture, or managing Zero
  Trust resources with Pulumi. For tunnel setup (the transport layer),
  also recall the cloudflare-tunnels skill. For deploying Access-protected
  apps via docker-compose, recall the arcane plugin's arcane-gitops skill.
---

# Cloudflare Zero Trust

Cloudflare Zero Trust (formerly Cloudflare for Teams) replaces traditional VPNs with identity-aware access policies. Every request is authenticated and authorized at Cloudflare's edge before reaching your application.

- **Docs**: <https://developers.cloudflare.com/cloudflare-one/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/zero-trust>

## Architecture

```
User → Cloudflare Edge → Access Policy Check → Tunnel → Your App
              ↓
     Identity Provider (IdP)
     (Google, GitHub, Okta, SAML, etc.)
```

The typical Zero Trust stack:

1. **Cloudflare Tunnel** — secure transport from Cloudflare to your origin (see `cloudflare-tunnels` skill)
2. **Access Application** — defines which hostname/path is protected
3. **Access Policy** — defines who can access it (based on identity, device, location, etc.)
4. **Gateway** (optional) — DNS/HTTP filtering for managed devices

## Access — Application Authentication

### Concepts

| Concept | Description |
|---------|-------------|
| **Application** | A hostname or path to protect (e.g., `app.example.com`) |
| **Policy** | Rules that determine who can access an application |
| **Identity Provider** | Where users authenticate (Google, GitHub, Okta, one-time PIN, etc.) |
| **Service Token** | Machine-to-machine auth (no human login) |
| **mTLS** | Mutual TLS certificate-based auth |
| **Session Duration** | How long an authenticated session lasts before re-auth |

### Supported Identity Providers

| Provider | Type | Setup Complexity |
|----------|------|-----------------|
| One-time PIN (email) | Built-in | None — works immediately |
| Google | OAuth | Add client ID/secret |
| GitHub | OAuth | Add client ID/secret |
| Okta | SAML/OIDC | Configure in Okta admin |
| Azure AD | SAML/OIDC | Configure in Azure portal |
| SAML (generic) | SAML | Any SAML 2.0 IdP |
| OpenID Connect (generic) | OIDC | Any OIDC provider |

### Policy Rules

Policies use **Include** (match any), **Exclude** (deny if matched), and **Require** (must match all):

| Rule Type | Examples |
|-----------|---------|
| Email | `user@example.com` |
| Email domain | `@example.com` |
| IP range | `192.168.1.0/24` |
| Country | US, GB, etc. |
| Authentication method | Specific IdP |
| Service token | Machine-to-machine |
| Device posture | WARP enrolled, OS version, disk encryption |
| External evaluation | Custom API check |

### Dashboard Setup

1. Go to **Zero Trust** → **Access** → **Applications**
2. Click **Add an application**
3. Choose **Self-hosted**
4. Set the **Application domain** (must match your tunnel's ingress hostname)
5. Configure **Identity providers** (or use one-time PIN for quick start)
6. Add **Policies** (e.g., "Allow @example.com emails")

### Protecting a Docker-Compose App

Typical flow for protecting a self-hosted app behind a tunnel:

```
1. Deploy app via docker-compose (on same network as cloudflared)
2. Create tunnel ingress rule:  app.example.com → http://my-app:8080
3. Create Access Application:   app.example.com
4. Create Access Policy:        Allow @example.com
5. Add DNS CNAME:               app.example.com → <tunnel-id>.cfargotunnel.com
```

If using Arcane for GitOps, the docker-compose stack goes in `hosts/<hostname>/<app>/docker-compose.yaml` and the Access configuration is managed via Pulumi (see below).

## Gateway — DNS & HTTP Filtering

Gateway provides network-level security for devices running the WARP client:

### DNS Policies

Block malicious domains, content categories, or specific domains:

```
Block security threats:      dns.security_category in {68 178 80}
Block social media:          dns.content_category in {171}
Block specific domain:       dns.fqdn == "example.com"
Allow exception:             dns.fqdn == "allowed.example.com"
```

### HTTP Policies

Inspect and filter HTTP traffic (requires WARP + TLS inspection):

```
Block file uploads:          http.request.method == "POST" and http.upload
Block malware downloads:     http.response.content_type matches "application/.*executable"
```

### Network Policies

Control traffic at the network layer:

```
Block SSH to external:       net.dst.port == 22 and not net.dst.ip in {10.0.0.0/8}
```

## WARP — Device Agent

WARP is the client-side agent that routes device traffic through Cloudflare:

- **DNS-only mode**: Routes DNS queries through Gateway (lightest)
- **WARP mode**: Routes all traffic through Cloudflare (full protection)
- **Split tunneling**: Only route specific IPs/domains through WARP

Install: <https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/download-warp/>

### Managed Deployment

```bash
# macOS (MDM)
# Deploy via Jamf, Kandji, etc. with a JSON config:
{
  "organization": "your-team-name",
  "auth_client_id": "<service-token-id>.access",
  "auth_client_secret": "<service-token-secret>"
}
```

## Pulumi IaC

### Access Application + Policy

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const cfConfig = new pulumi.Config("cloudflare");
const accountId = cfConfig.require("accountId");

// Look up the zone
const zone = cloudflare.getZoneOutput({ name: "example.com", accountId });

// Protect an application
const app = new cloudflare.ZeroTrustAccessApplication("internal-app", {
  zoneId: zone.id,
  name: "Internal Dashboard",
  domain: "dashboard.example.com",
  type: "self_hosted",
  sessionDuration: "24h",
  autoRedirectToIdentity: true,
  // Optional: custom logo, cors settings, etc.
  appLauncherVisible: true,
  logoUrl: "https://example.com/logo.png",
});

// Allow team members by email domain
const teamPolicy = new cloudflare.ZeroTrustAccessPolicy("allow-team", {
  applicationId: app.id,
  zoneId: zone.id,
  name: "Allow Team",
  precedence: 1,
  decision: "allow",
  includes: [{
    emailDomains: ["example.com"],
  }],
});

// Allow specific external users
const externalPolicy = new cloudflare.ZeroTrustAccessPolicy("allow-external", {
  applicationId: app.id,
  zoneId: zone.id,
  name: "Allow External Partners",
  precedence: 2,
  decision: "allow",
  includes: [{
    emails: ["partner@other.com"],
  }],
});

// Service token for machine-to-machine access (CI/CD, APIs)
const serviceToken = new cloudflare.ZeroTrustAccessServiceToken("api-token", {
  accountId,
  name: "CI/CD Pipeline",
  duration: "8760h", // 1 year
});

const apiPolicy = new cloudflare.ZeroTrustAccessPolicy("allow-service-token", {
  applicationId: app.id,
  zoneId: zone.id,
  name: "Allow Service Token",
  precedence: 3,
  decision: "non_identity",
  includes: [{
    serviceTokens: [serviceToken.id],
  }],
});

export const serviceTokenClientId = serviceToken.clientId;
export const serviceTokenClientSecret = serviceToken.clientSecret;
```

### Gateway DNS Policy

```typescript
// Block malware and phishing domains
const blockMalware = new cloudflare.ZeroTrustGatewayPolicy("block-malware", {
  accountId,
  name: "Block Security Threats",
  action: "block",
  enabled: true,
  filters: ["dns"],
  traffic: "any(dns.security_category[*] in {68 178 80 83})",
  description: "Block malware, phishing, cryptomining, and command-and-control domains",
});

// Block adult content
const blockAdult = new cloudflare.ZeroTrustGatewayPolicy("block-adult", {
  accountId,
  name: "Block Adult Content",
  action: "block",
  enabled: true,
  filters: ["dns"],
  traffic: "any(dns.content_category[*] in {4})",
  precedence: 2,
});

// Allow-list specific domains
const allowDocs = new cloudflare.ZeroTrustGatewayPolicy("allow-docs", {
  accountId,
  name: "Allow Documentation Sites",
  action: "allow",
  enabled: true,
  filters: ["dns"],
  traffic: 'dns.fqdn in {"docs.example.com" "wiki.example.com"}',
  precedence: 1, // Higher precedence = evaluated first
});
```

### Full Stack: Tunnel + Access + DNS

```typescript
// 1. Create tunnel (see cloudflare-tunnels skill)
const tunnel = new cloudflare.ZeroTrustTunnelCloudflared("app-tunnel", {
  accountId,
  name: "app-tunnel",
  secret: tunnelSecret,
});

// 2. Configure tunnel ingress
const tunnelConfig = new cloudflare.ZeroTrustTunnelCloudflaredConfig("app-tunnel-config", {
  accountId,
  tunnelId: tunnel.id,
  config: {
    ingressRules: [
      { hostname: "dashboard.example.com", service: "http://dashboard:3000" },
      { service: "http_status:404" },
    ],
  },
});

// 3. DNS record
const dns = new cloudflare.Record("dashboard-dns", {
  zoneId: zone.id,
  name: "dashboard",
  type: "CNAME",
  content: pulumi.interpolate`${tunnel.id}.cfargotunnel.com`,
  proxied: true,
});

// 4. Access protection
const accessApp = new cloudflare.ZeroTrustAccessApplication("dashboard", {
  zoneId: zone.id,
  name: "Dashboard",
  domain: "dashboard.example.com",
  type: "self_hosted",
  sessionDuration: "24h",
});

const accessPolicy = new cloudflare.ZeroTrustAccessPolicy("dashboard-policy", {
  applicationId: accessApp.id,
  zoneId: zone.id,
  name: "Allow Team",
  precedence: 1,
  decision: "allow",
  includes: [{ emailDomains: ["example.com"] }],
});
```

## Common Patterns

### Protect Admin Panels

Many self-hosted apps have admin panels that should be locked down:

| App | Path/Hostname | Policy |
|-----|---------------|--------|
| Nextcloud | `nextcloud.example.com` | Allow @example.com |
| n8n | `n8n.example.com` | Allow specific emails |
| Grafana | `grafana.example.com` | Allow @example.com |
| Portainer | `portainer.example.com` | Allow admin email only |
| Home Assistant | `ha.example.com` | Allow @example.com + require WARP |

### Bypass Access for APIs

If your app exposes a public API alongside a protected dashboard:

```typescript
// Protect the whole app
const app = new cloudflare.ZeroTrustAccessApplication("my-app", {
  domain: "app.example.com",
  // ...
});

// But allow unauthenticated access to /api/*
const bypassPolicy = new cloudflare.ZeroTrustAccessPolicy("bypass-api", {
  applicationId: app.id,
  zoneId: zone.id,
  name: "Bypass API",
  precedence: 0,
  decision: "bypass",
  includes: [{ anyValidServiceToken: {} }],
});
```

## Pricing

| Feature | Free (50 users) | Pay-as-you-go |
|---------|-----------------|---------------|
| Access | Included | $7/user/month |
| Gateway | Included | $7/user/month |
| WARP (Zero Trust) | Included | $7/user/month |
| Browser Isolation | — | $10/user/month |

The **free plan (50 users)** is generous for personal and small-team use.

## References

- [Zero Trust Docs](https://developers.cloudflare.com/cloudflare-one/)
- [Access Applications](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- [Access Policies](https://developers.cloudflare.com/cloudflare-one/policies/access/policy-management/)
- [Identity Providers](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/)
- [Service Tokens](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/)
- [Gateway Policies](https://developers.cloudflare.com/cloudflare-one/policies/gateway/)
- [Gateway DNS Categories](https://developers.cloudflare.com/cloudflare-one/policies/gateway/domain-categories/)
- [WARP Client](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/)
- [Pulumi ZeroTrustAccessApplication](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zerotrustaccessapplication/)
- [Pulumi ZeroTrustAccessPolicy](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zerotrustaccesspolicy/)
- [Pulumi ZeroTrustGatewayPolicy](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zerotrustgatewaypolicy/)
