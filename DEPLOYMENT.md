# Repertoire Builder Deployment Guide

This guide explains how to deploy the repertoire-builder application to your Oracle Cloud VPS using NixOS containers and deploy-rs.

## Overview

The deployment consists of:
- A native NixOS container running your repertoire-builder PocketBase application
- Tailscale for secure, private access (SSH is restricted to Tailscale only)
- Deploy-rs for automated deployments via Tailscale MagicDNS
- Proper networking and firewall configuration
- Persistent data storage

## Architecture

- **Project-level configuration**: The container configuration is defined in `container.nix` within the repertoire-builder project
- **Infrastructure loading**: The Oracle VPS configuration imports the container module from the repertoire-builder flake
- **Secrets Management**: Tailscale auth keys are managed via `agenix` in the `secrets/` directory.

## Prerequisites

1. Oracle Cloud VPS running NixOS
2. Tailscale installed and authenticated on your local machine
3. SSH public keys added to `secrets/secrets.nix` for agenix encryption
4. Nix with flakes enabled on your local machine

## Setup Steps

### 1. Tailscale Connectivity

Ensure you can reach the VPS via Tailscale:
```bash
ping oracle-0.tailc41cf5.ts.net
```

### 2. Update Flake Inputs

```bash
nix flake update
```

### 3. Build and Deploy

Enter the development shell:
```bash
nix develop
```

Or use just commands:
```bash
# Check configuration
just check

# Deploy to Oracle VPS
just deploy-oracle

# Deploy to Desktop
just deploy-desktop
```

## Container Details

The repertoire-builder runs in a native NixOS container with:

- **Network**: Private network with NAT
  - Host IP: `192.168.100.10`  
  - Container IP: `192.168.100.11`
- **Port**: Application serves on port `8090`
- **Data**: Persistent storage in `/var/lib/containers/repertoire-builder/data`
- **User**: Runs as `pocketbase` user for security

## Accessing the Application

Once deployed, you can access your repertoire-builder via Tailscale:
- External: `http://oracle-0:8090`
- PocketBase Admin: `http://oracle-0:8090/_/`

## Container Management

The `justfile` provides wrappers for container management using MagicDNS hostnames.

### Check Container Status
```bash
just container-status oracle-0
```

### View Container Logs
```bash
just container-logs oracle-0
```

### Restart Container
```bash
just container-restart oracle-0
```

### Enter Container Shell
```bash
just ssh-container oracle-0
```

## Security Notes

- **All public ports closed**: No direct access from internet
- **SSH via Tailscale only**: Port 22 closed on public interfaces
- **HTTP via Cloudflare Tunnel**: Outbound-only connection to Cloudflare edge
- **Agenix**: Secrets (Tailscale auth key, Cloudflare token) encrypted with SSH host keys

### Oracle Cloud Security List (Ingress)

| Type | Port | Purpose |
|------|------|---------|
| UDP | 41641 | Tailscale direct P2P |
| ICMP | Type 3 | Destination unreachable |
| ICMP | Type 3, Code 4 | Path MTU discovery |

All other ingress: **blocked**. Egress: **allow all**.

## Disaster Recovery: Rebuilding oracle-0

If the VPS is destroyed and you need to create a new one, follow these steps:

### 1. Create New VPS in Oracle Cloud

- Shape: `VM.Standard.A1.Flex` (ARM)
- Image: Ubuntu 22.04 (or latest LTS)
- **Keep SSH port 22 open** in security list (temporary for bootstrap)
- Note the public IP address

### 2. Install nixos-anywhere Locally (if not already)

```bash
nix profile install github:nix-community/nixos-anywhere
```

### 3. Get New Host's SSH Key

```bash
ssh-keyscan <new-ip> 2>/dev/null | grep ed25519
```

### 4. Update secrets.nix

Edit `secrets/secrets.nix` and replace the `oracle-0` key:

```nix
oracle-0 = "ssh-ed25519 AAAA...new-key...";
```

### 5. Re-encrypt All Secrets

```bash
cd secrets
agenix -r -i ~/.ssh/id_ed25519  # rekey all secrets with new host key
```

### 6. Commit the Changes

```bash
git add secrets/
git commit -m "Update oracle-0 host key for new VPS"
```

### 7. Run nixos-anywhere with Disko

This will:
- SSH into the Ubuntu instance
- Use kexec to boot into a NixOS installer (in RAM)
- Run disko to partition the disk (`/dev/sda`: 512M boot + rest as root)
- Install NixOS with your configuration

```bash
nixos-anywhere --flake .#oracle-0 root@<new-ip>
```

**Note:** The kexec boot takes 5-10 minutes. You may lose SSH connection temporarily.

### 8. Verify Tailscale Connectivity

After installation completes, the system will reboot. Wait a few minutes, then:

```bash
# Should work via Tailscale now
ssh matt@oracle-0
```

### 9. Lock Down Oracle Cloud Security List

Once Tailscale is working:
- **Remove** SSH port 22 ingress rule
- **Keep** UDP 41641 (Tailscale)
- **Keep** ICMP Type 3 (network health)

### 10. Verify Services

```bash
# Check tunnel is running
ssh matt@oracle-0 "sudo systemctl status cloudflared-tunnel"

# Test domains
curl https://cernohorsky.ca
curl https://chess.cernohorsky.ca
```

### Disko Disk Layout

The `disk-config.nix` defines partitioning for `/dev/sda`:

| Partition | Size | Type | Mount |
|-----------|------|------|-------|
| boot | 512M | EFI (vfat) | /boot |
| root | 100% | ext4 | / |

Disko runs automatically during `nixos-anywhere` - no manual partitioning needed.

### If nixos-anywhere Fails

Fall back to manual kexec method:

1. SSH into Ubuntu: `ssh ubuntu@<new-ip>`
2. Install nix: `curl -L https://nixos.org/nix/install | sh`
3. Build kexec tarball or use netboot.xyz
4. Boot into NixOS installer
5. Run disko manually: `nix run github:nix-community/disko -- --mode disko /path/to/disk-config.nix`
6. Mount and install: `nixos-install --flake .#oracle-0`

---

## Troubleshooting

### Host Key Verification Failed
If you change hostnames or IPs, you may need to clear old host keys:
```bash
ssh-keygen -R oracle-0.tailc41cf5.ts.net
ssh-keyscan -H oracle-0.tailc41cf5.ts.net >> ~/.ssh/known_hosts
```

### Deployment Timeout
If deployment times out during activation, it usually means the Tailscale connection was interrupted. Magic rollback will revert the changes automatically.
