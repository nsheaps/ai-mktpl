# Arcane GitOps Plugin

Skills for deploying docker-compose stacks via Arcane GitOps — directory conventions, secrets management with 1Password, and GitHub Actions CI/CD.

## Skills

| Skill | Description |
|-------|-------------|
| `arcane-gitops` | Full GitOps workflow: repo structure, init-secrets pattern with 1Password, shared networking, database initialization, image pinning, GitHub Actions deployment |

## Overview

Arcane syncs docker-compose stacks from a git repository to remote hosts. The skill covers:

- **Repository layout**: `hosts/<hostname>/<stack>/docker-compose.yaml`
- **Secrets pattern**: 1Password init-container sidecar for zero-plaintext secrets
- **Shared networks**: Named bridges (cloudflared, postgresql, redis) for inter-stack communication
- **Change detection**: Floating git tags track last deployment per stack
- **GitHub Actions**: 4-stage workflow (discover → set vars → deploy → tag)

## Related Plugins

- **cloudflare** — `cloudflare-tunnels` skill for Cloudflare Tunnel setup (commonly deployed via Arcane)
- **proxmox** — `proxmox-lxc` skill for setting up LXC hosts that run the docker-compose stacks
