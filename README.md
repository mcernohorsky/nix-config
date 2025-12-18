# Nix Configuration

This repository contains my personal Nix configuration for macOS using nix-darwin and home-manager.

## Setup

### Prerequisites

1. Install Nix:
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

2. Rename Computer:
```bash
sudo scutil --set ComputerName "macbook-pro-m2"
sudo scutil --set LocalHostName "macbook-pro-m2"
```

### Installation

1. Clone this repository:
```bash
git clone git@github.com:mcernohorsky/nix-config.git ~/.config/nix-config
```

2. Build and switch to the configuration:
```bash
nix run nix-darwin -- switch --flake ~/.config/nix-config
```

## Structure

- `flake.nix`: Main entry point and dependency declarations
- `hosts/`: Host-specific configurations
  - `macbook-pro-m2/`: macOS configuration
  - `matt-desktop/`: Linux desktop configuration
  - `oracle-0/`: Oracle Cloud NixOS VPS configuration
- `secrets/`: Encrypted secrets managed by `agenix`
- `templates/`: Nix flake templates for various languages
- `justfile`: Common commands for deployment and management

## Deployment

Deployments are handled via `deploy-rs` over Tailscale.

```bash
# Deploy to desktop
just deploy-desktop

# Deploy to Oracle VPS (via Docker)
just deploy-oracle
```

## Secrets

Secrets are stored in `secrets/*.age` and defined in `secrets/secrets.nix`.
To edit secrets:
```bash
agenix -e secrets/tailscale-authkey.age
```
