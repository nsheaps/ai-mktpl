---
name: cloudflare-dns
description: >
  Use this skill when the user asks about Cloudflare DNS, managing DNS
  records, domain zones, DNSSEC, proxied records, or managing DNS with Pulumi.
---

# Cloudflare DNS

Cloudflare DNS is one of the fastest authoritative DNS providers. It supports proxy mode (orange cloud), DNSSEC, wildcard records, and API-based management.

- **Docs**: <https://developers.cloudflare.com/dns/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/domains>
- **Pulumi resources**: `cloudflare.Zone`, `cloudflare.Record`

## Common Record Types

| Type  | Use Case                | Example                           |
| ----- | ----------------------- | --------------------------------- |
| A     | IPv4 address            | `example.com -> 1.2.3.4`          |
| AAAA  | IPv6 address            | `example.com -> 2001:db8::1`      |
| CNAME | Alias                   | `www -> example.com`              |
| MX    | Mail server             | `example.com -> mail.example.com` |
| TXT   | Verification, SPF, DKIM | `v=spf1 include:...`              |
| SRV   | Service discovery       | `_sip._tcp.example.com`           |

## Proxy Mode (Orange Cloud)

When `proxied: true`, Cloudflare's CDN, WAF, and DDoS protection apply to the record. When `proxied: false` (grey cloud), it's DNS-only.

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

// Zone
const zone = new cloudflare.Zone("example", {
  accountId,
  zone: "example.com",
});

// A Record
const www = new cloudflare.Record("www", {
  zoneId: zone.id,
  name: "www",
  type: "A",
  content: "1.2.3.4",
  proxied: true,
});

// CNAME Record
const api = new cloudflare.Record("api", {
  zoneId: zone.id,
  name: "api",
  type: "CNAME",
  content: "api-server.example.com",
  proxied: true,
});

// MX Record
const mx = new cloudflare.Record("mx", {
  zoneId: zone.id,
  name: "@",
  type: "MX",
  content: "mail.example.com",
  priority: 10,
});
```

## References

- [DNS Docs](https://developers.cloudflare.com/dns/)
- [Record Types](https://developers.cloudflare.com/dns/manage-dns-records/reference/dns-record-types/)
- [Proxy Status](https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/)
- [Pulumi Zone](https://www.pulumi.com/registry/packages/cloudflare/api-docs/zone/)
- [Pulumi Record](https://www.pulumi.com/registry/packages/cloudflare/api-docs/record/)
