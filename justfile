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

# Deploy to Linux Desktop
deploy-desktop:
    @echo "🚀 Deploying to Matt-Desktop..."
    deploy .#matt-desktop --skip-checks

# Deploy everything
deploy-all: deploy-desktop deploy-oracle

# Show container status on remote server
container-status HOST='oracle-0':
    ssh matt@{{HOST}} "sudo machinectl list"

# Check container logs on remote server
container-logs HOST='oracle-0':
    ssh matt@{{HOST}} "sudo journalctl -M repertoire-builder -f"

# Restart repertoire-builder container on remote server
container-restart HOST='oracle-0':
    ssh matt@{{HOST}} "sudo machinectl restart repertoire-builder"

# SSH into the host
ssh HOST='oracle-0':
    ssh matt@{{HOST}}

# SSH into the repertoire-builder container
ssh-container HOST='oracle-0':
    ssh matt@{{HOST}} "sudo machinectl shell repertoire-builder"
