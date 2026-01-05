# Justfile for NixOS deployment and management

# MagicDNS hostnames
oracle_host := "oracle-0.tailc41cf5.ts.net"
desktop_host := "matt-desktop.tailc41cf5.ts.net"

# Show available commands
default:
    @just --list

# Update flake inputs and opencode plugins
update:
    nix flake update
    just update-plugins

# Update opencode plugins versions in JSON
update-plugins:
    #!/usr/bin/env bash
    set -e
    echo "🔍 Checking for latest opencode plugin versions via registry..."
    OMO_VERSION=$(curl -s https://registry.npmjs.org/oh-my-opencode/latest | jq -r '.version')
    GOOGLE_ANTIGRAVITY_VERSION=$(curl -s https://registry.npmjs.org/opencode-google-antigravity-auth/latest | jq -r '.version')
    echo "oh-my-opencode: $OMO_VERSION"
    echo "opencode-google-antigravity-auth: $GOOGLE_ANTIGRAVITY_VERSION"
    jq -n --arg omo "$OMO_VERSION" --arg anti "$GOOGLE_ANTIGRAVITY_VERSION" \
        '{"oh-my-opencode": $omo, "opencode-google-antigravity-auth": $anti}' \
        > hosts/macbook-pro-m2/home/opencode-plugins.json
    echo "✅ Updated hosts/macbook-pro-m2/home/opencode-plugins.json"

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
#
# Notes:
# - Persistent /nix volume for build cache (dramatically faster deploys)
# - If "split brain" issues occur (stale cache), clear with: docker volume rm nix-config-store
# - Binary caches in flake.nix provide additional speedup
deploy-oracle:
    docker run --rm \
        --platform linux/arm64 \
        --security-opt seccomp=unconfined \
        -v $(pwd):/workspace \
        -v nix-config-store:/nix \
        -v ~/.ssh:/root/.ssh:ro \
        -w /workspace \
        --network host \
        -e NIX_CONFIG="experimental-features = nix-command flakes"$'\n'"accept-flake-config = true" \
        -e NIX_SSHOPTS="-o ServerAliveInterval=2 -o ServerAliveCountMax=30 -o ConnectTimeout=10 -o ConnectionAttempts=6" \
        nixos/nix:latest \
        nix run .#deploy-rs -- --skip-checks .#oracle-0

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

# Verify chess app deployment (backend + frontend versions)
verify-chess:
    @echo "🔍 Verifying chess.cernohorsky.ca deployment..."
    @echo ""
    @echo "Backend /api/version:"
    @curl -fsSL https://chess.cernohorsky.ca/api/version | jq .
    @echo ""
    @echo "Frontend /version.json:"
    @curl -fsSL https://chess.cernohorsky.ca/version.json | jq .
    @echo ""
    @echo "✅ Verification complete"

# Verify connectivity to all hosts
ping-all:
    @echo "Pinging oracle-0..."
    @ping -c 1 {{oracle_host}} > /dev/null && echo "✅ oracle-0 reachable" || echo "❌ oracle-0 unreachable"
    @echo "Pinging matt-desktop..."
    @ping -c 1 {{desktop_host}} > /dev/null && echo "✅ matt-desktop reachable" || echo "❌ matt-desktop unreachable"
