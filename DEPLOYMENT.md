# Repertoire Builder Deployment Guide

This guide explains how to deploy the repertoire-builder application to your Oracle Cloud VPS using NixOS containers and deploy-rs.

## Overview

The deployment consists of:
- A native NixOS container running your repertoire-builder PocketBase application
- Container configuration defined in the repertoire-builder project itself
- Deploy-rs for automated deployments
- Proper networking and firewall configuration
- Persistent data storage

## Architecture

- **Project-level configuration**: The container configuration is defined in `container.nix` within the repertoire-builder project
- **Infrastructure loading**: The Oracle VPS configuration imports the container module from the repertoire-builder flake
- **Separation of concerns**: The project defines how it should be containerized, infrastructure just loads it

## Prerequisites

1. Oracle Cloud VPS running NixOS (already configured)
2. SSH access to the VPS with your SSH key
3. The VPS user (`matt`) has sudo access
4. Nix with flakes enabled on your local machine

## Setup Steps

### 1. Update VPS Hostname

First, update the hostname in your flake.nix:

```nix
# In flake.nix, line ~101
hostname = "YOUR_ACTUAL_VPS_IP_OR_HOSTNAME"; # Replace with your VPS IP
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

# Deploy to VPS
just deploy
```

### 4. Verify Deployment

Check that the container is running:
```bash
just container-status YOUR_VPS_IP
```

Check application logs:
```bash
just container-logs YOUR_VPS_IP
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

Once deployed, you can access your repertoire-builder at:
- External: `http://YOUR_VPS_IP:8090`
- PocketBase Admin: `http://YOUR_VPS_IP:8090/_/`

## Container Management

### Check Container Status
```bash
ssh matt@YOUR_VPS_IP "sudo machinectl list"
```

### View Container Logs
```bash
ssh matt@YOUR_VPS_IP "sudo journalctl -M repertoire-builder -f"
```

### Restart Container
```bash
ssh matt@YOUR_VPS_IP "sudo machinectl restart repertoire-builder"
```

### Enter Container Shell
```bash
ssh matt@YOUR_VPS_IP "sudo machinectl shell repertoire-builder"
```

## Troubleshooting

### Container Won't Start
1. Check system logs: `sudo journalctl -u systemd-nspawn@repertoire-builder`
2. Check container config: `sudo systemctl status systemd-nspawn@repertoire-builder`
3. Verify data directory exists: `ls -la /var/lib/containers/repertoire-builder/`

### Network Issues
1. Check firewall: `sudo iptables -L -n`
2. Verify NAT rules: `sudo iptables -t nat -L -n`
3. Check container network: `sudo machinectl status repertoire-builder`

### Application Issues
1. Check service status inside container: `sudo machinectl shell repertoire-builder systemctl status repertoire-builder`
2. View application logs: `sudo journalctl -M repertoire-builder -u repertoire-builder`

### Build Failures
If you get hash mismatch errors, you may need to:
1. Update the repertoire-builder flake input
2. Clear Nix cache: `nix store gc`
3. Rebuild with `--rebuild-flake`

## Updating the Application

To update to a newer version of repertoire-builder:

1. Update the flake input:
   ```bash
   nix flake lock --update-input repertoire-builder
   ```

2. Deploy the update:
   ```bash
   just deploy
   ```

The container will be rebuilt with the new version automatically.

## Security Notes

- The container runs with limited privileges
- Data is stored outside the container for persistence
- Firewall rules restrict access to necessary ports only
- Application runs as non-root user inside container

## Backup

To backup your PocketBase data:
```bash
# On the VPS
sudo tar -czf repertoire-backup-$(date +%Y%m%d).tar.gz -C /var/lib/containers/repertoire-builder/data .
```

To restore:
```bash
# Stop container first
sudo machinectl stop repertoire-builder
# Restore data
sudo tar -xzf repertoire-backup-YYYYMMDD.tar.gz -C /var/lib/containers/repertoire-builder/data
# Start container
sudo machinectl start repertoire-builder
```