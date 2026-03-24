---
name: proxmox-lxc
description: >
  Use this skill when the user asks about Proxmox VE, LXC containers,
  creating containers on Proxmox, running Docker in LXC, setting up a
  lightweight host for services like cloudflared, or managing Proxmox
  infrastructure. For deploying services inside the LXC via docker-compose,
  also recall the arcane plugin's arcane-gitops skill. For Cloudflare Tunnel
  setup, recall the cloudflare plugin's cloudflare-tunnels skill.
---

# Proxmox VE — LXC Container Management

Proxmox VE (PVE) is an open-source server virtualization platform built on Debian. It supports both KVM virtual machines and **LXC containers** — lightweight, OS-level virtualization that shares the host kernel.

- **Docs**: <https://pve.proxmox.com/wiki/Main_Page>
- **LXC Docs**: <https://pve.proxmox.com/wiki/Linux_Container>
- **API Docs**: <https://pve.proxmox.com/pve-docs/api-viewer/>
- **Web UI**: `https://<proxmox-host>:8006`

## LXC vs VM

| Feature         | LXC Container          | KVM VM                  |
| --------------- | ---------------------- | ----------------------- |
| Boot time       | ~1 second              | ~30 seconds             |
| Memory overhead | Minimal                | ~256 MB+                |
| Kernel          | Shared with host       | Own kernel              |
| Isolation       | Namespace + cgroup     | Full hardware           |
| Performance     | Near-native            | Near-native (with VT-x) |
| Docker support  | Needs nesting          | Native                  |
| Use case        | Services, Docker hosts | Windows, custom kernels |

**Use LXC when**: running Linux services, Docker hosts, lightweight workloads.
**Use KVM when**: you need Windows, custom kernels, or strong isolation.

## Creating an LXC Container

### Via Web UI

1. Click **Create CT** in the top-right
2. **General**: Set hostname, password, VMID
3. **Template**: Choose an OS template (Debian 12, Ubuntu 24.04, etc.)
4. **Disks**: Set root disk size (8–20 GB typical)
5. **CPU**: Set cores (1–2 for light services)
6. **Memory**: Set RAM (512 MB for cloudflared, 2+ GB for Docker)
7. **Network**: Bridge, DHCP or static IP
8. **DNS**: Use host settings or custom
9. **Confirm**: Review and create

### Via CLI (`pct`)

```bash
# Download a template first
pveam update
pveam download local debian-12-standard_12.7-1_amd64.tar.zst

# Create an unprivileged container (most secure)
pct create 100 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname my-service \
  --memory 512 \
  --swap 256 \
  --cores 1 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --nameserver 1.1.1.1 \
  --unprivileged 1 \
  --start 1

# Enter the container
pct enter 100
```

### Common Parameters

| Parameter        | Example                          | Description                        |
| ---------------- | -------------------------------- | ---------------------------------- |
| `--hostname`     | `my-service`                     | Container hostname                 |
| `--memory`       | `2048`                           | RAM in MB                          |
| `--swap`         | `512`                            | Swap in MB                         |
| `--cores`        | `2`                              | CPU cores                          |
| `--rootfs`       | `local-lvm:20`                   | Storage and disk size (GB)         |
| `--net0`         | `name=eth0,bridge=vmbr0,ip=dhcp` | Network config                     |
| `--nameserver`   | `1.1.1.1`                        | DNS server                         |
| `--unprivileged` | `1`                              | Unprivileged (1) or privileged (0) |
| `--features`     | `nesting=1`                      | Enable container features          |
| `--onboot`       | `1`                              | Start on host boot                 |

## Running Docker in LXC

Docker works in **unprivileged containers** on Proxmox 8.x+ with `nesting=1` and `keyctl=1` features enabled. This is the recommended approach — more secure than privileged containers.

### Create a Docker-Ready LXC (Unprivileged — Recommended)

```bash
pct create 101 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname docker-host \
  --memory 4096 \
  --swap 1024 \
  --cores 4 \
  --rootfs local-lvm:50 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1,keyctl=1 \
  --unprivileged 1 \
  --onboot 1 \
  --start 1
```

Key settings:

- `--unprivileged 1` — Unprivileged container (recommended, more secure)
- `--features nesting=1,keyctl=1` — Both required for Docker in unprivileged LXC
- More memory/disk than a plain service container

To enable on an existing container (or via UI: **Options > Features > check nesting + keyctl**):

```bash
pct set 101 --features nesting=1,keyctl=1
```

### Install Docker Inside the LXC

```bash
pct enter 101

# Install Docker
curl -fsSL https://get.docker.com | sh

# Verify
docker run --rm hello-world

# Install docker-compose plugin
apt install -y docker-compose-plugin

# Verify
docker compose version
```

### Unprivileged vs Privileged

| Aspect        | Unprivileged (recommended) | Privileged                           |
| ------------- | -------------------------- | ------------------------------------ |
| Security      | UID-mapped; escape = nobody on host | Container root = host root         |
| Docker        | Works with `nesting=1,keyctl=1` | Works out of the box               |
| Limitations   | Cannot mount SMB/CIFS directly | Full host access on escape         |
| ZFS caveat    | Needs ext4 formatted volume | Native ZFS driver works            |

### When to Use a VM Instead

- You need live migration between Proxmox nodes
- You need Docker overlay/macvlan networking
- You want maximum isolation (zero risk of host kernel exploits)
- You run GPU-passthrough workloads

### Known Gotcha

Docker/containerd updates inside LXC can break with `net.ipv4.ip_unprivileged_port_start` permission errors. Pin or test containerd.io versions before upgrading. **Snapshot before upgrading** the host OS or Docker.

## Use Case: cloudflared in LXC

### Option A: Direct Install (No Docker)

Lightest option — run `cloudflared` as a systemd service:

```bash
# Create a minimal unprivileged LXC
pct create 200 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname cloudflared \
  --memory 256 \
  --swap 128 \
  --cores 1 \
  --rootfs local-lvm:4 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --onboot 1 \
  --start 1

pct enter 200

# Install cloudflared
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bookworm main" \
  | tee /etc/apt/sources.list.d/cloudflared.list
apt update && apt install -y cloudflared

# Install as a service with your tunnel token
cloudflared service install <TUNNEL_TOKEN>
systemctl enable --now cloudflared

# Verify
systemctl status cloudflared
```

Resources: 256 MB RAM, 1 core, 4 GB disk — minimal footprint.

### Option B: Docker in LXC (for full docker-compose stacks)

If you want to run multiple services (cloudflared + apps) via docker-compose:

```bash
# Create a Docker-ready LXC (see above)
pct create 201 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname docker-host \
  --memory 4096 \
  --cores 2 \
  --rootfs local-lvm:30 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1,keyctl=1 \
  --unprivileged 1 \
  --onboot 1 \
  --start 1

pct enter 201

# Install Docker
curl -fsSL https://get.docker.com | sh

# Deploy cloudflared + services via docker-compose
# See the cloudflare plugin's cloudflare-tunnels skill for compose files
# See the arcane plugin's arcane-gitops skill for GitOps deployment
```

## Managing LXC Containers

### Common Operations

```bash
# List all containers
pct list

# Start/stop/restart
pct start 100
pct stop 100
pct restart 100

# Enter container shell
pct enter 100

# Run a command inside container
pct exec 100 -- apt update

# Resize disk
pct resize 100 rootfs +10G

# Change resources (requires stop)
pct set 100 --memory 4096 --cores 4

# Snapshot
pct snapshot 100 before-upgrade
pct rollback 100 before-upgrade

# Clone
pct clone 100 102 --hostname clone-of-100

# Destroy (permanently delete)
pct destroy 100
```

### Backup and Restore

```bash
# Backup
vzdump 100 --storage local --mode snapshot --compress zstd

# Restore
pct restore 103 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst
```

### Resource Monitoring

```bash
# CPU and memory usage
pct status 100

# Detailed status
pct config 100

# Via Proxmox API
curl -s "https://proxmox:8006/api2/json/nodes/<node>/lxc/100/status/current" \
  -H "Authorization: PVEAPIToken=<user>!<token>=<secret>"
```

## Automation

### Proxmox API

All operations available via REST API:

```bash
# Create container via API
curl -X POST "https://proxmox:8006/api2/json/nodes/<node>/lxc" \
  -H "Authorization: PVEAPIToken=user@pam!mytoken=<secret>" \
  -d "vmid=100" \
  -d "hostname=my-container" \
  -d "ostemplate=local:vztmpl/debian-12-standard.tar.zst" \
  -d "memory=2048" \
  -d "cores=2" \
  -d "rootfs=local-lvm:20" \
  -d "net0=name=eth0,bridge=vmbr0,ip=dhcp" \
  -d "unprivileged=1" \
  -d "start=1"
```

### Terraform / Pulumi

Community providers for Proxmox IaC:

- **Terraform**: [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) (actively maintained, supports PVE 8.x and 9.x)
- **Pulumi**: [@muhlba91/pulumi-proxmoxve](https://www.pulumi.com/registry/packages/proxmoxve/) (wraps bpg provider; TypeScript, Python, Go, C#)

```typescript
// Pulumi example — create an LXC container
import * as proxmox from "@muhlba91/pulumi-proxmoxve";

const provider = new proxmox.Provider("pve", {
  endpoint: "https://pve.example.com:8006/",
  apiToken: "root@pam!pulumi=<secret>",
  insecure: true,
});

const ct = new proxmox.ct.Container(
  "docker-host",
  {
    nodeName: "pve",
    vmId: 101,
    operatingSystem: {
      templateFileId:
        "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst",
      type: "debian",
    },
    disk: { datastoreId: "local-lvm", size: 20 },
    cpu: { cores: 2 },
    memory: { dedicated: 2048 },
    networkInterface: { name: "eth0", bridge: "vmbr0" },
    features: { nesting: true, keyctl: true },
    unprivileged: true,
  },
  { provider },
);
```

> **Note**: Creating multiple containers in parallel can cause Proxmox lock errors. Use sequential creation or `parallelism: 1` in Terraform.
```

## Best Practices

### Container Sizing

| Workload              | Memory | Cores | Disk   |
| --------------------- | ------ | ----- | ------ |
| cloudflared (direct)  | 256 MB | 1     | 4 GB   |
| Single service        | 512 MB | 1     | 8 GB   |
| Docker host (light)   | 2 GB   | 2     | 20 GB  |
| Docker host (heavy)   | 4+ GB  | 4     | 50+ GB |
| Database (PostgreSQL) | 2+ GB  | 2     | 20+ GB |

### Security

- **Always use unprivileged** containers (Docker works with `nesting=1,keyctl=1`)
- **One role per container** — don't mix unrelated services
- **Use onboot=1** for critical infrastructure (cloudflared, databases)
- **Regular snapshots** before upgrades
- **Firewall rules** via Proxmox's built-in firewall for inter-container traffic

### Networking

- **Bridge mode** (`vmbr0`): Containers get IPs on the LAN (simplest)
- **VLAN tagging**: `--net0 name=eth0,bridge=vmbr0,tag=100` for network segmentation
- **Static IPs**: `--net0 name=eth0,bridge=vmbr0,ip=10.0.0.100/24,gw=10.0.0.1`

## References

- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [LXC Containers](https://pve.proxmox.com/wiki/Linux_Container)
- [PCT CLI Reference](https://pve.proxmox.com/pve-docs/pct.1.html)
- [Proxmox API](https://pve.proxmox.com/pve-docs/api-viewer/)
- [Docker in LXC](https://pve.proxmox.com/wiki/Linux_Container#pct_container_types)
- [Unprivileged LXC Containers](https://pve.proxmox.com/wiki/Unprivileged_LXC_containers)
- [Terraform bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest)
- [Pulumi proxmoxve Provider](https://www.pulumi.com/registry/packages/proxmoxve/)
- [Proxmox Community Helper Scripts](https://community-scripts.github.io/ProxmoxVE/)
