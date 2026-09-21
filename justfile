# Justfile for Nix host deployment and management

# MagicDNS hostnames
oracle_host := "oracle-0.tailc41cf5.ts.net"
desktop_host := "matt-desktop.tailc41cf5.ts.net"

desktop_ssh := "tailscale ssh matt@" + desktop_host

# Show available commands
default:
    @just --list

# Update flake inputs
update:
    nix flake update

# Update just the repertoire-builder input
update-app:
    nix flake update repertoire-builder

# Update just the HEX voice dictation inputs (flake for Linux, Homebrew tap for macOS)
update-hex:
    nix flake update hex hex-homebrew-tap

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
    @{{desktop_ssh}} 'if [ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f /run/current-system/kernel)" ] || ! nvidia-smi >/dev/null 2>&1; then echo "⚠️  Kernel changed or NVIDIA is unavailable; reboot matt-desktop"; else echo "✅ Running kernel and NVIDIA stack do not require a reboot"; fi'

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

# SSH into a host (defaults to oracle-0, e.g. `just ssh matt-desktop.tailc41cf5.ts.net`)
ssh host=oracle_host:
    ssh matt@{{host}}

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

# Verify connectivity to all hosts; exit non-zero if any host is unreachable
ping-all:
    #!/usr/bin/env bash
    set -u
    fail=0
    ping -c 1 {{oracle_host}} > /dev/null && echo "✅ oracle-0 reachable" || { echo "❌ oracle-0 unreachable" >&2; fail=1; }
    ping -c 1 {{desktop_host}} > /dev/null && echo "✅ matt-desktop reachable" || { echo "❌ matt-desktop unreachable" >&2; fail=1; }
    exit $fail

# Desktop OpenCode v2 managed-service commands

# Check Desktop OpenCode managed service status
desktop-opencode-status:
    @echo "Desktop OpenCode managed service:"
    @{{desktop_ssh}} '"$HOME/.bun/bin/opencode" service status'
    @echo ""
    @echo "Tailscale Serve config:"
    @{{desktop_ssh}} "tailscale serve status"

# View Desktop Tailscale sync logs
desktop-opencode-logs:
    @{{desktop_ssh}} "journalctl -u opencode-tailscale-sync.service -f"

# Restart the Desktop managed service, then re-sync Serve (also exercises
# the port-change watcher path end to end)
desktop-opencode-restart:
    @{{desktop_ssh}} '"$HOME/.bun/bin/opencode" service restart && sleep 5 && sudo systemctl start opencode-tailscale-sync.service && tailscale serve status'
    @echo "✅ Restarted managed service and re-synced Tailscale Serve"

# Tailscale policy-file management (policy_file-scoped OAuth client in
# agenix; short-lived tokens minted per run). Apply prompts for YES unless
# --yes is passed to the binary directly.

# Show the live tailnet policy file
tailscale-policy-show:
    tailscale-policy show

# Diff the repo policy against the live one
tailscale-policy-diff:
    tailscale-policy diff tailscale-acl.json

# Apply the repo policy (guarded by the live ETag; prompts for YES)
tailscale-policy-apply:
    tailscale-policy apply tailscale-acl.json
