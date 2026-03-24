---
name: arcane-gitops
description: >
  Use this skill when the user asks about Arcane GitOps, deploying
  docker-compose stacks from a git repo, GitOps for self-hosted services,
  managing docker-compose stacks declaratively, or setting up automated
  deployments with Arcane and GitHub Actions. Also recall when the user
  asks about deploying cloudflared, Nextcloud, n8n, or any docker-compose
  stack via GitOps. For Cloudflare Tunnel setup details, also recall the
  cloudflare plugin's cloudflare-tunnels skill. For LXC host setup, recall
  the proxmox plugin's proxmox-lxc skill.
---

# Arcane GitOps for Docker Compose

Arcane is a GitOps tool that syncs docker-compose stacks from a git repository to remote hosts. Push to `main`, and Arcane deploys. It provides a Portainer-like experience driven entirely by code in your repo.

## How It Works

```
Git Push → GitHub Actions → Arcane API → Host Agent → docker compose up
```

1. You define docker-compose stacks in a git repo under `hosts/<hostname>/<stack>/`
2. A GitHub Actions workflow detects changes and calls the Arcane API
3. Arcane pushes the updated stack to the target host
4. The host agent runs `docker compose up -d` to apply changes
5. Arcane also polls every ~5 minutes for drift detection

## Repository Structure

```
iac/
├── hosts/
│   ├── README.md
│   ├── _example/                    # Template for new stacks
│   └── <hostname>/                  # One directory per host
│       ├── cloudflared/
│       │   └── docker-compose.yaml
│       ├── postgresql/
│       │   └── docker-compose.yaml
│       ├── redis/
│       │   └── docker-compose.yaml
│       ├── nextcloud/
│       │   └── docker-compose.yaml
│       └── n8n/
│           └── docker-compose.yaml
├── arcane/
│   └── hosts/
│       └── <hostname>/
│           └── arcane.json          # Host-level Arcane config
├── apps/                            # Reusable compose modules (optional)
│   └── README.md
└── .github/
    └── workflows/
        └── arcane-deploy.yaml       # GitOps deployment workflow
```

### Naming Conventions

- **Host directories**: `hosts/<hostname>/` — match the actual hostname
- **Stack directories**: `hosts/<hostname>/<stack-name>/` — descriptive service name
- **Compose files**: Must end in `-compose.yaml` or `-compose.yml`
- **Arcane config**: `arcane/hosts/<hostname>/arcane.json`

### Host Config (`arcane.json`)

```json
{
  "environment_id": "0"
}
```

The `environment_id` ties the host to an Arcane deployment environment.

## Docker Compose Patterns

### Secret Management with 1Password

Every stack that needs secrets follows the **init-secrets pattern**: a sidecar container fetches secrets from 1Password before the main service starts.

```yaml
name: my-app

services:
  init-secrets:
    image: 1password/op:2
    user: "0:0"
    environment:
      - OP_SERVICE_ACCOUNT_TOKEN=${OP_SERVICE_ACCOUNT_TOKEN}
    volumes:
      - app-secrets:/run/secrets:rw
    command: |
      /bin/bash -c
      fetch "op://Infrastructure/my-app/db-password" "/run/secrets/db_password" &
      fetch "op://Infrastructure/my-app/api-key"     "/run/secrets/api_key"     &
      wait
      chmod 444 /run/secrets/*

  my-app:
    image: my-app:latest
    restart: always
    volumes:
      - app-secrets:/run/secrets:ro
    depends_on:
      init-secrets:
        condition: service_completed_successfully
    networks:
      - cloudflared

volumes:
  app-secrets:
    driver: local

networks:
  cloudflared:
    external: true
```

Key points:
- `OP_SERVICE_ACCOUNT_TOKEN` is injected by Arcane as a global variable
- Secrets are fetched in parallel (`&` + `wait`) for speed
- Secrets volume is `:rw` for init, `:ro` for app
- `chmod 444` makes secrets read-only after creation
- `depends_on` with `service_completed_successfully` ensures secrets exist before app starts

### 1Password Path Convention

```
op://<vault>/<item>/<field>

# Examples:
op://Infrastructure/my-server--my-app/password
op://Infrastructure/my-server--postgres--root-user/username
op://Infrastructure/my-server--postgres--root-user/password
```

Convention: `<host>--<service>--<component>/<field>`

### Networking

Stacks share named networks for inter-service communication:

```yaml
# In the cloudflared stack (creates the network):
networks:
  cloudflared:
    driver: bridge
    name: cloudflared

# In any stack that needs tunnel access (joins the network):
networks:
  cloudflared:
    external: true
```

Common shared networks:
- `cloudflared` — services exposed via Cloudflare Tunnel
- `postgresql` — services needing database access
- `redis` — services needing cache/queue access

### Database Initialization

Stacks that need a database include an init container:

```yaml
services:
  init-database:
    image: postgres:17
    depends_on:
      init-secrets:
        condition: service_completed_successfully
    volumes:
      - app-secrets:/run/secrets:ro
    networks:
      - postgresql
    entrypoint: /bin/bash
    command: |
      -c "
      export PGPASSWORD=$(cat /run/secrets/root_password)
      # Create user and database if they don't exist
      psql -h postgresql -U postgres -tc \"SELECT 1 FROM pg_roles WHERE rolname='myapp'\" | grep -q 1 || \
        psql -h postgresql -U postgres -c \"CREATE USER myapp WITH PASSWORD '$(cat /run/secrets/db_password)';\"
      psql -h postgresql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname='myapp'\" | grep -q 1 || \
        psql -h postgresql -U postgres -c \"CREATE DATABASE myapp OWNER myapp;\"
      "
```

### Reusable Compose Modules

The `apps/` directory holds shared compose configurations included via the `include` directive:

```yaml
# In a host-specific compose file:
include:
  - ../../../apps/monitoring/docker-compose.yaml
```

**Constraint**: Included apps must have identical configuration across all hosts. No parameterization — if values differ, copy the compose file instead.

### Image Pinning

Pin images by digest for reproducibility:

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:2026.3.0@sha256:6b599ca3e974...
```

Use Renovate to auto-update pinned digests.

## GitHub Actions Deployment Workflow

### Workflow Overview

The `arcane-deploy.yaml` workflow has four stages:

1. **discover** — Scan `arcane/hosts/` for changed projects using floating git tags
2. **set-global-vars** — Upsert `OP_SERVICE_ACCOUNT_TOKEN` in Arcane
3. **deploy** — Matrix job: deploy each changed stack via Arcane API
4. **tag** — Update deployment tags (e.g., `deployed/arcane/heapsnas/cloudflared`)

### Change Detection

Uses floating git tags to track last deployment:

```
Tag: deployed/arcane/<host>/<project>
```

On each deploy, the tag moves to the current commit. Next run compares HEAD against the tag to detect changes. Force deploy (via workflow input) ignores tags and redeploys everything.

### Authentication

- **GitHub App** for repo access and bot commits
- **SSH deploy key** (from 1Password) for Arcane API authentication
- **1Password Service Account Token** for runtime secret access

## Adding a New Stack

1. Create the directory:
   ```bash
   mkdir -p hosts/<hostname>/<stack-name>
   ```

2. Add docker-compose.yaml following the patterns above

3. If secrets are needed, add them to 1Password under `Infrastructure/<hostname>--<stack-name>`

4. If the service needs external access, join the `cloudflared` network and configure the tunnel hostname in Cloudflare dashboard (or via Pulumi)

5. Commit and push to `main`:
   ```bash
   git add hosts/<hostname>/<stack-name>/
   git commit -m "feat(<hostname>): add <stack-name> stack"
   git push
   ```

6. The GitHub Actions workflow deploys automatically

## Monitoring Deployments

- **GitHub Actions**: Check the `arcane-deploy` workflow runs
- **Arcane Dashboard**: View stack status and logs
- **Docker on host**: `docker compose -f /path/to/stack/docker-compose.yaml ps`

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- [1Password CLI Docker Image](https://hub.docker.com/r/1password/op)
