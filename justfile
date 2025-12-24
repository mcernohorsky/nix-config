# Justfile for NixOS deployment and management

# MagicDNS hostnames
oracle_host := "oracle-0.tailc41cf5.ts.net"
desktop_host := "matt-desktop.tailc41cf5.ts.net"

# Show available commands
default:
    @just --list

# Update flake inputs
update:
    nix flake update

# Update just the repertoire-builder input
update-app:
    nix flake lock --update-input repertoire-builder

# Enter development shell with deploy-rs
dev:
    nix develop

# Build Oracle VPS configuration locally
build-oracle:
    nix build .#nixosConfigurations.oracle-0.config.system.build.toplevel

# Deploy to Oracle VPS using NixOS Docker container
deploy-oracle:
    @echo "🚀 Deploying to Oracle VPS using NixOS Docker container..."
    @echo "Container config is loaded from repertoire-builder project"
    docker run --rm \
        --platform linux/arm64 \
        --security-opt seccomp=unconfined \
        -v $(pwd):/workspace \
        -v nix-config-store:/nix \
        -v ~/.ssh:/root/.ssh:ro \
        -w /workspace \
        --network host \
        -e NIX_CONFIG="experimental-features = nix-command flakes" \
        nixos/nix:latest \
        nix --experimental-features 'nix-command flakes' run github:serokell/deploy-rs -- --skip-checks .#oracle-0

# Deploy to Linux Desktop (remote build via Tailscale)
deploy-desktop:
    @echo "🚀 Deploying to matt-desktop..."
    nix run nixpkgs#deploy-rs -- .#matt-desktop --skip-checks

# Deploy to macbook (this machine)
deploy-mac:
    @echo "🚀 Deploying to macbook-pro-m2..."
    sudo darwin-rebuild switch --flake .

# Deploy everything (parallel)
deploy-all:
    just deploy-oracle &
    just deploy-desktop &
    just deploy-mac
    @wait
    @echo "✅ All deployments complete"

# Show container status on remote server
container-status host=oracle_host:
    ssh matt@{{host}} "sudo machinectl list"

# Check container logs on remote server
container-logs host=oracle_host:
    ssh matt@{{host}} "sudo journalctl -M repertoire-builder -f"

# Restart repertoire-builder container on remote server
container-restart host=oracle_host:
    ssh matt@{{host}} "sudo machinectl restart repertoire-builder"

# SSH into a host (defaults to oracle-0)
ssh host=oracle_host:
    ssh matt@{{host}}

# SSH into oracle-0
ssh-oracle:
    ssh matt@{{oracle_host}}

# SSH into matt-desktop
ssh-desktop:
    ssh matt@{{desktop_host}}

# SSH into the repertoire-builder container
ssh-container host=oracle_host:
    ssh matt@{{host}} "sudo machinectl shell repertoire-builder"

# Check Tailscale status of all hosts
tailscale-status:
    @echo "Local Tailscale status:"
    @tailscale status | grep -E "(oracle|matt-desktop)"

# Verify connectivity to all hosts
ping-all:
    @echo "Pinging oracle-0..."
    @ping -c 1 {{oracle_host}} > /dev/null && echo "✅ oracle-0 reachable" || echo "❌ oracle-0 unreachable"
    @echo "Pinging matt-desktop..."
    @ping -c 1 {{desktop_host}} > /dev/null && echo "✅ matt-desktop reachable" || echo "❌ matt-desktop unreachable"
