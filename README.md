# Nix Configuration

This repository contains my personal Nix configuration for macOS using nix-darwin and home-manager.

## Setup

### Prerequisites

1. Install Nix:
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

2. Enable Flakes:
```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/nix-config.git ~/.config/nix-config
```

2. Build and switch to the configuration:
```bash
cd ~/.config/nix-config
nix build .#darwinConfigurations.macbook-pro-m2.system
./result/sw/bin/darwin-rebuild switch --flake .#macbook-pro-m2
```

## Structure

- `flake.nix`: Main entry point and dependency declarations
- `home.nix`: Home-manager configuration
- `hosts/`: Host-specific configurations
  - `macbook-pro-m2/`: Configuration specific to MacBook Pro M2
- `home/`: User-specific configurations
  - `neovim/`: Neovim configuration

## Features

- Terminal: Ghostty with custom configuration
- Shell: Fish and Zsh (configurable)
- Editor: Neovim
- Package Management: Mix of Nix packages and Homebrew casks
- System Preferences: Custom macOS settings

## Updating

To update the system:
```bash
nix flake update
darwin-rebuild switch --flake .#macbook-pro-m2
```
