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

## Vaultwarden & Backups

Vaultwarden is deployed as a native service on `oracle-0`, accessible only via Tailscale at `https://oracle-0.tailc41cf5.ts.net`.

### Backup Strategy
Backups are performed every 6 hours using Restic to two locations:
1. **Cloudflare R2**: Offsite encrypted backup (`oracle-0-backups` bucket).
2. **matt-desktop**: Local encrypted backup via SFTP to `/backups/oracle-0/vaultwarden`.

Note: If `matt-desktop` is powered off, the local backup job will fail. This is normal and the job will succeed on the next run once the desktop is online.

### Secrets
The following secrets are required in `secrets/`:
- `vaultwarden-admin-token.age`: Argon2 hash for the admin panel.
- `restic-password.age`: Encryption password for the Restic repositories.
- `restic-r2-credentials.age`: Cloudflare R2 Access Key ID and Secret Access Key.

### Disaster Recovery: Restoring Vaultwarden

If you need to restore Vaultwarden to a new `oracle-0` instance:

1. **Deploy the base system** following the "Disaster Recovery: Rebuilding oracle-0" steps above.
2. **Stop Vaultwarden**:
   ```bash
   ssh matt@oracle-0 "sudo systemctl stop vaultwarden"
   ```
3. **Restore from Cloudflare R2**:
   ```bash
   ssh matt@oracle-0 << 'EOF'
   sudo -i
   export AWS_ACCESS_KEY_ID=$(grep AWS_ACCESS_KEY_ID /run/secrets/restic-r2-credentials | cut -d= -f2)
   export AWS_SECRET_ACCESS_KEY=$(grep AWS_SECRET_ACCESS_KEY /run/secrets/restic-r2-credentials | cut -d= -f2)
   export RESTIC_PASSWORD_FILE=/run/secrets/restic-password
   export RESTIC_REPOSITORY="s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups"
   
   # List snapshots to verify connectivity
   restic snapshots
   
   # Restore the latest snapshot to the root filesystem
   restic restore latest --target /
   EOF
   ```
4. **Restart Vaultwarden**:
   ```bash
   ssh matt@oracle-0 "sudo systemctl start vaultwarden"
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

### Tailscale ACL Policy

The network uses a tiered trust model defined in `tailscale-acl.json`:

| Tag | Devices | Access |
|-----|---------|--------|
| `tag:trusted` | matt-desktop | Full access to all devices |
| `tag:cloud` | oracle-0 | Isolated; can only reach trusted on compute ports |
| *(user identity)* | macbook, phone, iPad | Full access via `autogroup:member` |

**Apply the policy:** Copy contents of `tailscale-acl.json` to [Tailscale Admin Console → Access Controls](https://login.tailscale.com/admin/acls)

### Taildrive Setup

Taildrive enables secure file sharing between trusted devices. After applying the ACL policy:

```bash
# On Linux (matt-desktop), share a directory:
tailscale drive share my-files /path/to/directory

# Access shares from any trusted device:
# Linux: mount via WebDAV at http://100.100.100.100:8080/<tailnet>/<machine>/<share>
# macOS: Finder → Go → Connect to Server → http://100.100.100.100:8080/
```

Note: oracle-0 has no Taildrive access (intentional isolation).

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

## matt-desktop BIOS Configuration

Reference settings for the AMD Ryzen 7 5700X3D workstation. These settings were optimized for stability and performance on the ASUS ROG STRIX B450-F GAMING motherboard with 64GB (2x32GB) DDR4 RAM.

**Last updated**: December 2025 (BIOS version 5901)

### Hardware Summary

| Component | Details |
|-----------|---------|
| CPU | AMD Ryzen 7 5700X3D (8-core, 96MB L3 V-Cache) |
| Motherboard | ASUS ROG STRIX B450-F GAMING |
| RAM | Corsair Vengeance LPX 64GB (2x32GB) DDR4-3200 CL16 (CMK64GX4M2E3200C16) |
| RAM Slots | DIMM_A2 + DIMM_B2 (optimal for dual-channel) |
| GPU | NVIDIA GeForce RTX 2070 8GB |

### Ai Tweaker Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Ai Overclock Tuner | Manual | DOCP fails with 64GB dual-rank on B450 |
| Memory Frequency | DDR4-3200MHz | |
| FCLK Frequency | 1600 MHz | 1:1 ratio with memory |
| DRAM Voltage | 1.365V | Slight bump from 1.35V spec for stability |
| CPU SOC Voltage | Manual: 1.100V | Feeds memory controller and Infinity Fabric |

### Ai Tweaker → DRAM Timing Control

| Setting | Value |
|---------|-------|
| DRAM CAS# Latency (tCL) | 16 |
| DRAM RAS# to CAS# Read Delay (tRCDrd) | 20 |
| DRAM RAS# to CAS# Write Delay (tRCDwr) | 20 |
| DRAM RAS# PRE Time (tRP) | 20 |
| DRAM RAS# ACT Time (tRAS) | 38 |
| Cmd2T (Command Rate) | 2T |

### Advanced → AMD CBS → NBIO Common Options → XFR Enhancement

| Setting | Value | Notes |
|---------|-------|-------|
| Precision Boost Overdrive | Enabled | Allows optimal CPU boost using motherboard limits |

Note: Curve Optimizer is not available for 5700X3D on this BIOS.

### Boot Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Fast Boot | Disabled | Ensures full memory training on each boot |
| CSM | Disabled | Required for Resizable BAR |

### Advanced → PCI Subsystem Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Above 4G Decoding | Enabled | Required for Resizable BAR |
| Re-Size BAR Support | Enabled | ~5-10% GPU performance in supported games |

### Thermal Performance

Verified stable under load:
- Idle: ~37°C
- Full 16-thread stress: ~49°C peak

### Why These Settings?

- **Manual RAM config**: DOCP/XMP fails to train with 64GB dual-rank on B450 due to signal integrity limits
- **2T Command Rate**: Required for stability with high-density dual-rank DIMMs
- **3200 MT/s (not higher)**: The 5700X3D's 96MB L3 cache masks RAM speed differences; gains from 3600+ are <1.5% but stability risks are high
- **PBO limits**: Conservative values protect B450 VRMs while allowing full CPU boost
- **Fast Boot disabled**: Ensures proper memory training; critical for 64GB on B450

### Recovery

If system fails to POST after changes:
1. Power off, switch off PSU
2. Wait 30 seconds
3. Power on — board should auto-recover to safe mode (C.P.R. feature)
4. Re-enter BIOS and adjust settings

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

---

## Deployment Verification Checklist

After every deployment, verify these to confirm success:

### 1. Backend Version
```bash
curl https://chess.cernohorsky.ca/api/version
```
Expected: JSON with `version`, `gitCommit`, `buildTime`

### 2. Frontend Version
```bash
curl https://chess.cernohorsky.ca/version.json
```
Expected: JSON matching the deployment commit

### 3. UI Footer
Check the app footer shows the version (e.g., `v0.1.0 (abc1234)`)

### 4. Container & Service Health
```bash
just container-status oracle-0
ssh matt@oracle-0 "sudo systemctl status container@repertoire-builder"
ssh matt@oracle-0 "sudo machinectl shell repertoire-builder /bin/systemctl status repertoire-builder"
ssh matt@oracle-0 "sudo machinectl shell repertoire-builder /bin/systemctl status pocketbase-superuser-setup"
```

### 5. pb_public Mount Verification
```bash
ssh matt@oracle-0 "sudo machinectl shell repertoire-builder /bin/ls -la /var/lib/pocketbase/pb_public"
```
Expected: Shows files from the Nix store (read-only mount)

### 6. Database Persistence
```bash
ssh matt@oracle-0 "sudo sqlite3 /var/lib/containers/repertoire-builder/data/data.db 'SELECT COUNT(*) FROM edges;'"
```
Compare with API result to verify same database is being used.

### 7. Service Restart Test
```bash
just container-restart oracle-0
# Wait 30 seconds, then verify:
curl https://chess.cernohorsky.ca/api/health
curl https://chess.cernohorsky.ca/version.json
```
Expected: No "missing assets" window, services come up cleanly

---

## If Frontend Didn't Update (Rare)

If `/version.json` shows an old commit after deployment:

1. **Clear Docker nix store volume** (on build machine):
   ```bash
   docker volume rm nix-config-store
   just deploy-oracle
   ```

2. **Do NOT** bump version numbers or modify derivation inputs as a workaround.

The root cause is usually Docker volume cache corruption. Clearing the volume forces a fresh evaluation and build.
