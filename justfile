# Justfile for NixOS deployment and management

# MagicDNS hostnames
oracle_host := "oracle-0.tailc41cf5.ts.net"
desktop_host := "matt-desktop.tailc41cf5.ts.net"

# Show available commands
default:
    @just --list

# Update flake inputs and fast-moving AI tool pins
update:
    nix flake update
    just update-plugins

# Update opencode plugins versions in JSON
update-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking for latest opencode plugin versions via registry..."
    CURSOR_OAUTH_VERSION=$(bun -e 'const res = await fetch("https://registry.npmjs.org/opencode-cursor-oauth/latest"); if (!res.ok) throw new Error(`registry request failed: ${res.status}`); const pkg = await res.json(); console.log(pkg.version)')
    echo "opencode-cursor-oauth: $CURSOR_OAUTH_VERSION"
    jq -n --arg cursor "$CURSOR_OAUTH_VERSION" \
        '{"opencode-cursor-oauth": $cursor}' \
        > modules/home/opencode-plugins.json
    echo "✅ Updated modules/home/opencode-plugins.json"

# Update just the repertoire-builder input
update-app:
    nix flake update repertoire-builder

# Enter development shell with deploy-rs
dev:
    nix develop

# Build Oracle VPS configuration locally
build-oracle:
    nix build .#nixosConfigurations.oracle-0.config.system.build.toplevel

# Deploy to Oracle VPS with Determinate Nix's native Linux builder.
deploy-oracle:
    @echo "🚀 Deploying to oracle-0 with the native Linux builder..."
    nix run .#deploy-rs -- .#oracle-0 --skip-checks

# Build on the Linux desktop and stage the result for its next boot. Boot-only
# activation avoids mixing a new NVIDIA userspace with the loaded kernel module.
deploy-desktop:
    @echo "🚀 Building and staging matt-desktop for its next boot..."
    nix run .#deploy-rs -- --boot .#matt-desktop --skip-checks
    @echo "✅ matt-desktop is staged; reboot it when convenient to activate the new generation"

# Deploy to macbook (this machine)
deploy-mac:
    @echo "🚀 Deploying to macbook-pro-m2..."
    sudo env NIX_CONFIG='accept-flake-config = true' darwin-rebuild switch --flake .

# Deploy all hosts in parallel; failures propagate through Just's dependency graph.
[parallel]
deploy-all: deploy-oracle deploy-desktop deploy-mac
    @echo "✅ Deployments complete; matt-desktop will activate on its next reboot"

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

# Desktop OpenCode web service commands
# Access from iPhone: https://matt-desktop.tailc41cf5.ts.net

# Check Desktop OpenCode web service status
desktop-opencode-status:
    @echo "Desktop OpenCode web service:"
    @ssh matt@{{desktop_host}} "systemctl status opencode-web --no-pager"
    @echo ""
    @echo "Tailscale Serve config:"
    @ssh matt@{{desktop_host}} "tailscale serve status"

# View Desktop OpenCode web service logs
desktop-opencode-logs:
    @ssh matt@{{desktop_host}} "journalctl -u opencode-web -f"

# Restart Desktop OpenCode web service
desktop-opencode-restart:
    @ssh matt@{{desktop_host}} "sudo systemctl restart opencode-web opencode-web-serve"
    @echo "✅ Restarted opencode-web and opencode-web-serve services"

# Reset Desktop Tailscale Serve config
desktop-opencode-reset-serve:
    @ssh matt@{{desktop_host}} "tailscale serve reset && tailscale serve --bg http://127.0.0.1:4097"
    @echo "✅ Reset Tailscale Serve to proxy to localhost:4097"
