# Justfile for Nix host deployment and management

# MagicDNS hostnames
oracle_host := "oracle-0.tailc41cf5.ts.net"
desktop_host := "matt-desktop.tailc41cf5.ts.net"
mac_host := "macbook-pro-m2.tailc41cf5.ts.net"

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

# Update the Tinycast Homebrew tap (including its pinned cask version)
update-tinycast:
    nix flake update tinycast-homebrew-tap

# Enter development shell with deploy-rs
dev:
    nix develop

# Build Oracle VPS configuration locally
build-oracle:
    nix build .#nixosConfigurations.oracle-0.config.system.build.toplevel

# Deploy to Oracle VPS. macOS builds ARM via Determinate's native Linux
# builder; Linux builds via local binfmt emulation (see
# boot.binfmt.emulatedSystems on matt-desktop).
deploy-oracle:
    @echo "🚀 Deploying to oracle-0..."
    nix run .#deploy-rs -- .#oracle-0 --skip-checks

# Deploy the Linux desktop: remotely from macOS, locally on Linux.
[macos]
deploy-desktop:
    @echo "🚀 Deploying to matt-desktop..."
    nix run .#deploy-rs -- .#matt-desktop --skip-checks
    @{{desktop_ssh}} 'if [ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f /run/current-system/kernel)" ] || ! nvidia-smi >/dev/null 2>&1; then echo "⚠️  Kernel changed or NVIDIA is unavailable; reboot matt-desktop"; else echo "✅ Running kernel and NVIDIA stack do not require a reboot"; fi'

# Deploy to macbook: locally on macOS, over SSH from Linux (password
# prompts work through the allocated tty).
[macos]
deploy-mac:
    @echo "🚀 Deploying to macbook-pro-m2..."
    sudo env NIX_CONFIG='accept-flake-config = true' darwin-rebuild switch --flake .

[linux]
deploy-mac:
    @echo "🚀 Deploying to macbook-pro-m2 over SSH..."
    ssh -t matt@{{mac_host}} 'cd ~/.config/nix-config && nix develop -c just deploy-mac'

[linux]
deploy-desktop:
    @echo "🚀 Deploying to matt-desktop (local)..."
    sudo nixos-rebuild switch --flake .#matt-desktop

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

# T3 Code serves the three local providers from each host. Pairing links are
# one-time credentials, so generate them only when adding a device.
t3-status:
    @"$HOME/.local/bin/t3" service status
    @{{desktop_ssh}} '"$HOME/.local/bin/t3" service status'

t3-pair-mac:
    @"$HOME/.local/bin/t3" pair --tailscale

t3-pair-desktop:
    @{{desktop_ssh}} '"$HOME/.local/bin/t3" pair --tailscale'

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
