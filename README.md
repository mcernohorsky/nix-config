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
- `home.nix`: Home-manager configuration
- `hosts/`: Host-specific configurations
  - `macbook-pro-m2/`: Configuration specific to MacBook Pro M2
- `home/`: User-specific configurations
  - `neovim/`: Neovim configuration

## Updating

To update the system:
```bash
nix flake update
darwin-rebuild switch --flake ~/.config/nix-config
```
