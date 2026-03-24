---
name: cloudflare-zero-trust
description: >
  Use this skill when the user asks about Cloudflare Zero Trust, Access
  policies, identity-based access control, WARP client, Gateway DNS
  filtering, or managing Zero Trust resources with Pulumi.
---

# Cloudflare Zero Trust

Cloudflare Zero Trust (formerly Cloudflare for Teams) replaces VPNs with identity-aware access policies. It includes Access (application-level auth), Gateway (DNS/HTTP filtering), and WARP (device agent).

- **Docs**: <https://developers.cloudflare.com/cloudflare-one/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/zero-trust>

## Components

### Access — Application Authentication

Protect web apps with identity-based policies. No code changes needed.

```
User -> Cloudflare Access (identity check) -> Your App (behind Tunnel)
```

**Pulumi**:

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const accessApp = new cloudflare.ZeroTrustAccessApplication("my-app", {
  zoneId: zone.id,
  name: "My Internal App",
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
    emails: ["user@example.com"],
  }],
});
```

### Gateway — DNS & HTTP Filtering

Filter DNS queries and HTTP traffic for security and compliance.

**Pulumi**:

```typescript
const dnsPolicy = new cloudflare.ZeroTrustGatewayPolicy("block-malware", {
  accountId,
  name: "Block Malware",
  action: "block",
  enabled: true,
  filters: ["dns"],
  traffic: 'any(dns.security_category[*] in {68 178 80})',
});
```

### WARP — Device Agent

Route device traffic through Cloudflare for DNS filtering, split tunneling, and device posture checks.

## Pricing

| Feature | Free (50 users) | Pay-as-you-go |
|---------|-----------------|---------------|
| Access | Included | $7/user/month |
| Gateway | Included | $7/user/month |
| WARP | Included | $7/user/month |

## References

- [Zero Trust Docs](https://developers.cloudflare.com/cloudflare-one/)
- [Access](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- [Gateway](https://developers.cloudflare.com/cloudflare-one/policies/gateway/)
- [Pulumi ZeroTrustAccessApplication](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zerotrustaccessapplication/)
