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
    just update-openchamber

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

# Update OpenChamber web pin + lockfile from the latest npm release
update-openchamber:
    #!/usr/bin/env bash
    set -euo pipefail
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT
    META_JSON="$TMPDIR/openchamber-meta.json"

    echo "🔍 Checking for latest @openchamber/web version via registry..."
    bun -e 'const out = process.argv[1]; const res = await fetch("https://registry.npmjs.org/@openchamber/web/latest"); if (!res.ok) throw new Error(`registry request failed: ${res.status}`); const pkg = await res.json(); await Bun.write(out, `${JSON.stringify({ version: pkg.version, url: pkg.dist.tarball, srcHash: pkg.dist.integrity }, null, 2)}\n`)' "$META_JSON"

    VERSION=$(jq -r '.version' "$META_JSON")
    URL=$(jq -r '.url' "$META_JSON")
    echo "@openchamber/web: $VERSION"

    mkdir -p "$TMPDIR/extract"
    curl -fsSL "$URL" | tar -xzf - -C "$TMPDIR/extract"
    (cd "$TMPDIR/extract/package" && npm install --package-lock-only --ignore-scripts >/dev/null)
    cp "$TMPDIR/extract/package/package-lock.json" hosts/macbook-pro-m2/modules/openchamber-package-lock.json

    NPM_DEPS_HASH=$(nix run nixpkgs#prefetch-npm-deps -- hosts/macbook-pro-m2/modules/openchamber-package-lock.json)
    jq --arg npmDepsHash "$NPM_DEPS_HASH" '. + { npmDepsHash: $npmDepsHash }' "$META_JSON" > hosts/macbook-pro-m2/modules/openchamber-pin.json

    echo "✅ Updated hosts/macbook-pro-m2/modules/openchamber-pin.json"
    echo "✅ Updated hosts/macbook-pro-m2/modules/openchamber-package-lock.json"

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
        -e NIX_CONFIG="experimental-features = nix-command flakes"$'\n'"accept-flake-config = true"$'\n'"extra-substituters = https://install.determinate.systems"$'\n'"extra-trusted-public-keys = cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=" \
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
    sudo env NIX_CONFIG='accept-flake-config = true' darwin-rebuild switch --flake .

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

# OpenChamber (OpenCode web UI) commands
# Access from iPhone: https://macbook-pro-m2.tailc41cf5.ts.net

# Check OpenChamber service status
openchamber-status:
    @echo "OpenChamber launchd agent:"
    @launchctl list | grep openchamber || echo "Not running"
    @echo ""
    @echo "Tailscale Serve config:"
    @tailscale serve status

# View OpenChamber logs
openchamber-logs:
    @tail -f ~/Library/Logs/openchamber.log

# Restart OpenChamber service
openchamber-restart:
    launchctl kickstart -k gui/$(id -u)/org.nix-community.home.openchamber

# Reset Tailscale Serve config (useful after port changes)
openchamber-reset-serve:
    tailscale serve reset
    tailscale serve --bg http://127.0.0.1:3000

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
