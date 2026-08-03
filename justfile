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

# Update the official OpenCode v2 beta CLI on both agent hosts
opencode-update:
    @echo "Updating OpenCode v2 beta on macbook-pro-m2..."
    bun install -g --trust @opencode-ai/cli@next
    @echo "Updating OpenCode v2 beta on matt-desktop..."
    ssh matt@{{desktop_host}} 'bun install -g --trust @opencode-ai/cli@next'
    @echo "Mac:     $($HOME/.bun/bin/opencode2 --version)"
    @ssh matt@{{desktop_host}} 'printf "Desktop: "; "$HOME/.bun/bin/opencode2" --version'

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

# Build on and deploy to the Linux desktop over Tailscale.
deploy-desktop:
    @echo "🚀 Deploying to matt-desktop..."
    nix run .#deploy-rs -- .#matt-desktop --skip-checks
    @ssh matt@{{desktop_host}} 'if [ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f /run/current-system/kernel)" ] || ! nvidia-smi >/dev/null 2>&1; then echo "⚠️  Kernel changed or NVIDIA is unavailable; reboot matt-desktop"; else echo "✅ Running kernel and NVIDIA stack do not require a reboot"; fi'

# Deploy to macbook (this machine)
deploy-mac:
    @echo "🚀 Deploying to macbook-pro-m2..."
    sudo env NIX_CONFIG='accept-flake-config = true' darwin-rebuild switch --flake .

# Deploy all hosts in parallel; failures propagate through Just's dependency graph.
[parallel]
deploy-all: deploy-oracle deploy-desktop deploy-mac
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

# Desktop OpenCode v2 service commands

# Check Desktop OpenCode service status
desktop-opencode-status:
    @echo "Desktop OpenCode v2 service:"
    @ssh matt@{{desktop_host}} "systemctl status opencode-v2 --no-pager"
    @echo ""
    @echo "Tailscale Serve config:"
    @ssh matt@{{desktop_host}} "tailscale serve status"

# View Desktop OpenCode service logs
desktop-opencode-logs:
    @ssh matt@{{desktop_host}} "journalctl -u opencode-v2 -f"

# Restart Desktop OpenCode service
desktop-opencode-restart:
    @ssh matt@{{desktop_host}} "sudo systemctl restart opencode-v2 opencode-v2-serve"
    @echo "✅ Restarted opencode-v2 and opencode-v2-serve services"

# Reset Desktop Tailscale Serve config
desktop-opencode-reset-serve:
    @ssh matt@{{desktop_host}} "tailscale serve reset && tailscale serve --bg http://127.0.0.1:4097"
    @echo "✅ Reset Tailscale Serve to proxy to localhost:4097"
