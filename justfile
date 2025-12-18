# Justfile for NixOS deployment and management

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

# Deploy to Oracle VPS (replace YOUR_VPS_IP_OR_HOSTNAME in flake.nix first)
deploy-oracle:
    @echo "🚀 Deploying to Oracle VPS using NixOS Docker container..."
    @echo "Make sure you've updated the hostname in flake.nix!"
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

# Deploy to Linux Desktop
deploy-desktop:
    @echo "🚀 Deploying to Matt-Desktop..."
    deploy .#matt-desktop --skip-checks

# Deploy with verbose output
deploy-verbose:
    @echo "🚀 Deploying to Oracle VPS with verbose output using NixOS Docker container..."
    docker run --rm \
        --security-opt seccomp=unconfined \
        -v $(pwd):/workspace \
        -v nix-config-store:/nix/store \
        -v ~/.ssh:/root/.ssh:ro \
        -w /workspace \
        --network host \
        nixos/nix:latest \
        nix --experimental-features 'nix-command flakes' run github:serokell/deploy-rs -- --skip-checks .#oracle-0 --debug-logs

# Check deployment configuration
check:
    nix flake check

# Show container status on remote server (requires SSH access)
container-status IP:
    ssh matt@{{IP}} "sudo machinectl list"

# Check container logs on remote server
container-logs IP:
    ssh matt@{{IP}} "sudo journalctl -M repertoire-builder -f"

# Restart repertoire-builder container on remote server
container-restart IP:
    ssh matt@{{IP}} "sudo machinectl restart repertoire-builder"

# SSH into the Oracle VPS
ssh IP:
    ssh matt@{{IP}}

# SSH into the repertoire-builder container
ssh-container IP:
    ssh matt@{{IP}} "sudo machinectl shell repertoire-builder"
