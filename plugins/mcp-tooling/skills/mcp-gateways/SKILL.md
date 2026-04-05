---
name: mcp-gateways
description: >
  Use this skill when working with MCP gateways — infrastructure for running MCP
  servers off-host, sharing them between sessions/clients, and federating multiple
  servers behind a single endpoint. Use when the user asks about remote MCP servers,
  MCP multiplexing, sharing MCP tools across teams, securing MCP over networks,
  transport bridging (stdio to SSE/HTTP), or choosing between gateway solutions
  like Supergateway, mcp-proxy, ContextForge, Envoy AI Gateway, or AgentGateway.
---

# MCP Gateways

MCP gateways sit between AI clients and MCP servers, providing centralized management, security, transport bridging, and server federation. They solve the problem of sharing MCP servers across sessions, teams, and networks.

## Why Use an MCP Gateway

| Problem                                    | Gateway Solution                                 |
| ------------------------------------------ | ------------------------------------------------ |
| Each session spawns duplicate MCP servers  | Single shared server instance behind the gateway |
| stdio servers can't be accessed remotely   | Transport bridge: stdio → SSE/HTTP               |
| Multiple servers need separate connections | Federation: one endpoint, all tools              |
| No centralized auth or access control      | Gateway handles auth, RBAC, rate limiting        |
| No visibility into tool usage              | Centralized observability and logging            |
| Credentials scattered in configs           | Gateway manages credential lifecycle             |

## When to Use Each Pattern

| Scenario                                  | Recommended Approach                                |
| ----------------------------------------- | --------------------------------------------------- |
| Expose a local stdio server over HTTP     | Supergateway or mcp-proxy                           |
| Share servers between local sessions      | mcp-proxy daemoning (see mcp-proxy-daemoning skill) |
| Enterprise multi-team MCP federation      | ContextForge, Kong, or liteLLM                      |
| AWS-hosted MCP with IAM auth              | AWS MCP Proxy                                       |
| Kubernetes-native MCP routing             | AgentGateway or Envoy AI Gateway                    |
| Quick debugging/testing of remote servers | Supergateway (one-liner)                            |

## Popular Gateway Implementations

### 1. Supergateway

**Repository**: https://github.com/supercorp-ai/supergateway

The simplest way to expose a stdio MCP server over HTTP. One command, no installation required.

```bash
# Expose any stdio MCP server via SSE
npx -y supergateway --stdio "uvx mcp-server-git"

# Via WebSocket
npx -y supergateway --stdio "uvx mcp-server-git" --transport ws

# Via Streamable HTTP
npx -y supergateway --stdio "uvx mcp-server-git" --transport streamablehttp

# With authentication
npx -y supergateway --stdio "uvx mcp-server-git" --oauth2

# Docker deployment
docker run -p 8000:8000 supercorp/supergateway --stdio "mcp-server-git"
```

**Best for**: Quick transport bridging, debugging, exposing local servers to remote clients.

### 2. mcp-proxy (sparfenyuk)

**Repository**: https://github.com/sparfenyuk/mcp-proxy

Bidirectional transport adapter between stdio and SSE/StreamableHTTP.

```bash
# Install
uv tool install mcp-proxy
# or: pipx install mcp-proxy
# or: docker pull ghcr.io/sparfenyuk/mcp-proxy

# Mode 1: stdio client → remote SSE server
# (lets Claude Desktop connect to remote SSE servers)
mcp-proxy http://example.io/sse

# Mode 2: expose local stdio server as SSE
# (lets remote clients connect to your local server)
mcp-proxy --port=8080 uvx mcp-server-fetch
```

**Features**: Named servers at different paths, OAuth2, CORS, SSL control, environment variable management.

**Best for**: Bridging transport mismatches between clients and servers.

### 3. ContextForge (IBM)

**Repository**: https://github.com/IBM/mcp-context-forge

Enterprise registry and proxy that federates MCP servers, A2A agents, and REST/gRPC APIs.

```bash
pip install mcp-contextforge-gateway
# or: Docker Compose with PostgreSQL and Redis
# or: Kubernetes Helm charts
```

**Features**:

- Federates multiple MCP servers into one unified endpoint
- Translates gRPC services to MCP via server reflection
- Wraps REST APIs as MCP-compliant tools
- Built-in auth, retries, rate limiting
- OpenTelemetry observability
- Admin UI for management
- Supports airgapped deployments

**Best for**: Enterprise environments needing unified governance over many MCP servers.

### 4. AWS MCP Proxy

**Repository**: https://github.com/aws/mcp-proxy-for-aws

Client-side proxy for connecting to AWS-hosted MCP servers with SigV4 authentication.

```bash
uvx mcp-proxy-for-aws@latest <endpoint-url> \
    --service <aws-service> \
    --region <aws-region> \
    --profile <credential-profile> \
    --read-only
```

**Best for**: Connecting local MCP clients to AWS-hosted MCP servers with IAM auth.

### 5. Envoy AI Gateway

**Documentation**: https://aigateway.envoyproxy.io/docs/

Enterprise API gateway with first-class MCP support.

```bash
aigw run --mcp-config claude_desktop_config.json
```

**Features**:

- Token-encoding architecture (stateless sessions)
- Reconnection with Last-Event-ID for SSE
- Merges multiple backend SSE streams into single client stream
- Full Envoy networking stack (load balancing, circuit breaking, rate limiting)

**Best for**: Organizations already using Envoy, needing production-grade MCP routing.

### 6. AgentGateway

**Documentation**: https://agentgateway.dev/docs/

MCP multiplexing proxy with automatic tool namespacing.

```yaml
http:
  listeners:
    - port: 3000
      route: /${path}
      backend: mcp_backend

backends:
  mcp_backend:
    type: mcp
    targets:
      time: http://time-server:8080
      everything: http://everything-server:8080
```

Tools from all backends are visible at one endpoint, namespaced as `${backend_name}_${tool_name}`.

**Features**: Label-based federation for Kubernetes, automatic service discovery, virtual MCP per-client.

**Best for**: Kubernetes environments with multiple MCP servers needing federation.

### 7. liteLLM

**Documentation**: https://docs.litellm.ai/docs/mcp

Unified gateway for LLMs, agents, and MCP.

```yaml
mcp_servers:
  - name: "git"
    transport: "streamable_http"
    url: "https://example.io/mcp"
    auth_type: "oauth"
    auth_config:
      client_id: "..."
      client_secret: "..."
```

**Features**: Single endpoint for 100+ LLM models + MCP tools, access control by API key/team/org, multi-auth (OAuth, SigV4, API keys, bearer, basic).

**Best for**: Teams already using liteLLM for LLM routing who also need MCP.

### 8. Kong AI Gateway

**Documentation**: https://konghq.com/products/kong-ai-gateway

Enterprise API gateway with MCP server generation from REST APIs.

**Features**: Native MCP server generation from REST endpoints (no coding), OAuth 2.1, RBAC, multi-protocol (OIDC, SAML, SSO), purpose-built MCP traffic observability.

**Best for**: Enterprise API management with existing Kong infrastructure.

## Security Considerations for Off-Host MCP

### Transport Security

- **Always use TLS** for MCP connections over networks (HTTPS, WSS)
- **Never expose** raw stdio or unencrypted SSE endpoints to the internet
- Use a reverse proxy (nginx, Caddy) with TLS termination if the gateway doesn't handle TLS natively

### Authentication Patterns

| Pattern       | When to Use                               |
| ------------- | ----------------------------------------- |
| OAuth 2.1     | Multi-user environments, external clients |
| Bearer tokens | Single-user, trusted network              |
| AWS SigV4     | AWS-hosted servers                        |
| mTLS          | High-security, machine-to-machine         |
| No auth       | Local-only (localhost, Docker network)    |

### Access Control

- **Tool-level RBAC**: Restrict which tools each user/team can access
- **Read-only mode**: Some gateways support `--read-only` to prevent write operations
- **Rate limiting**: Prevent abuse and control costs
- **Audit logging**: Track who called which tools and when

### Network Architecture

```
# Secure pattern: gateway on private network, TLS at edge

Internet ──TLS──→ Reverse Proxy ──→ MCP Gateway ──→ MCP Servers
                   (Caddy/nginx)     (private)       (private)

# Secure pattern: VPN/tunnel for remote access

Remote Client ──WireGuard──→ MCP Gateway ──→ MCP Servers
                              (LAN only)     (LAN only)

# Secure pattern: SSH tunnel for ad-hoc access

Local Client ──SSH tunnel──→ Remote Host ──→ MCP Gateway:12476
```

### Credential Management

- **Never embed credentials** in MCP server configs that are committed to git
- Use environment variable substitution (`${API_KEY}`) in configs
- Store secrets in OS keychains, vault systems, or CI/CD secret stores
- Gateway-level credential management centralizes secret handling

## Architecture Decision Guide

```
Do you need remote access to MCP servers?
├─ No → mcp-proxy daemoning (local daemon, see mcp-proxy-daemoning skill)
└─ Yes
   ├─ Quick/temporary access? → Supergateway (one command)
   ├─ Transport mismatch? → mcp-proxy (sparfenyuk)
   ├─ AWS-hosted servers? → AWS MCP Proxy
   └─ Production/enterprise?
      ├─ Already use Envoy? → Envoy AI Gateway
      ├─ Already use Kong? → Kong AI Gateway
      ├─ Already use liteLLM? → liteLLM MCP
      ├─ Kubernetes-native? → AgentGateway
      └─ Need full federation + admin UI? → ContextForge
```
