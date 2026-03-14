# AGENTS.md

## Overview

Personal Nix infrastructure-as-code repository managing three machines:
- **macbook-pro-m2** (aarch64-darwin) — nix-darwin + home-manager
- **matt-desktop** (x86_64-linux) — NixOS + Hyprland
- **oracle-0** (aarch64-linux) — NixOS cloud VPS hosting services (chess app, Vaultwarden, monitoring)

See `README.md` for structure and `DEPLOYMENT.md` for deployment procedures.

## Cursor Cloud specific instructions

### Nix daemon

The cloud VM runs without systemd, so the nix-daemon must be started manually. The update script handles this, but if the daemon dies mid-session, restart it with:

```bash
sudo /nix/var/nix/profiles/default/bin/nix-daemon &>/dev/null &
sleep 2
```

### Dev shell

Enter the development shell (provides `deploy-rs`, `just`, `git`, `ssh-to-age`) with:

```bash
nix develop
```

Or run a single command inside the dev shell:

```bash
nix develop --command just --list
```

### Validation commands

- **Lint/check the flake:** `nix flake check` — validates templates, devShells, deploy-rs checks, and NixOS configurations.
- **Evaluate a specific config value:** `nix eval .#nixosConfigurations.matt-desktop.config.networking.hostName`
- **List just recipes:** `nix develop --command just --list`

### Known limitations in cloud VM

- **`repertoire-builder` input:** This is a private repository (`git+ssh://git@github.com/mcernohorsky/repertoire-builder`). Without the owner's SSH key, `oracle-0` NixOS configuration and deploy-rs checks that depend on it will fail to evaluate. The `matt-desktop` configuration, dev shell, templates, and apps all evaluate independently.
- **No remote deployment:** `just deploy-*` commands require Tailscale connectivity and SSH keys to the target machines, which are not available in the cloud VM.
- **Binary caches:** The flake defines extra substituters (nix-community, hyprland, deploy-rs). These are configured in `/etc/nix/nix.conf` by the update script.
