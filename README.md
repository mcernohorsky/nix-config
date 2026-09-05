# Nix Configuration

This repository contains my personal Nix configurations: macOS via nix-darwin and NixOS, all with home-manager.

## Setup

### Prerequisites

1. Install Determinate Nix on macOS:
```bash
open https://install.determinate.systems/determinate-pkg/stable/Universal
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
just deploy-mac
```

3. Verify Determinate Nix:
```bash
nix --version
determinate-nixd version
```

## Structure

- `flake.nix`: Main entry point and dependency declarations
- `hosts/`: Host-specific configurations
  - `macbook-pro-m2/`: macOS configuration
  - `matt-desktop/`: Linux desktop configuration
  - `oracle-0/`: Oracle Cloud NixOS VPS configuration
- `modules/`: Shared home-manager modules
- `packages/`: Local package definitions
- `secrets/`: Encrypted secrets managed by `agenix`
- `templates/`: Nix flake templates for various languages
- `justfile`: Common commands for deployment and management

## Deployment

Deployments run via `deploy-rs` over Tailscale; see [DEPLOYMENT.md](DEPLOYMENT.md).

```bash
just deploy-mac      # this machine
just deploy-desktop  # NixOS workstation (reports if a reboot is advisable)
just deploy-oracle   # Oracle VPS (Determinate native Linux builder)
```

## Secrets

Secrets are stored in `secrets/*.age` and defined in `secrets/secrets.nix`.
To edit secrets:
```bash
agenix -e secrets/tailscale-authkey.age
```
