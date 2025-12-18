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

- **SSH is restricted to Tailscale only**: Port 22 is closed on public interfaces.
- **Direct Connections**: Open UDP port 41641 inbound in the Oracle Cloud security list for optimal performance.
- **Agenix**: Secrets are encrypted using SSH host keys.

## Troubleshooting

### Host Key Verification Failed
If you change hostnames or IPs, you may need to clear old host keys:
```bash
ssh-keygen -R oracle-0.tailc41cf5.ts.net
ssh-keyscan -H oracle-0.tailc41cf5.ts.net >> ~/.ssh/known_hosts
```

### Deployment Timeout
If deployment times out during activation, it usually means the Tailscale connection was interrupted. Magic rollback will revert the changes automatically.
