# Proxmox VE Plugin

Skills for managing Proxmox VE hosts and LXC containers — creating containers, running Docker in LXC, and hosting services.

## Skills

| Skill | Description |
|-------|-------------|
| `proxmox-lxc` | LXC container management: creating containers via UI/CLI, running Docker in LXC (privileged + nesting), cloudflared deployment, resource sizing, Proxmox API automation |

## Overview

LXC containers on Proxmox provide lightweight, near-native-performance virtualization for Linux services. The skill covers:

- **LXC basics**: Create, configure, and manage containers via `pct` CLI or web UI
- **Docker in LXC**: Privileged containers with nesting for running docker-compose stacks
- **cloudflared hosting**: Both direct install (256 MB) and Docker-in-LXC approaches
- **Resource sizing**: Guidelines for different workloads
- **Automation**: Proxmox API, Terraform provider, Pulumi integration

## Related Plugins

- **cloudflare** — `cloudflare-tunnels` skill for tunnel configuration (cloudflared runs inside the LXC)
- **arcane** — `arcane-gitops` skill for deploying docker-compose stacks to the LXC host
