# Nix Configuration

nix-darwin, NixOS, and Home Manager for three hosts:

| Host | Role |
| --- | --- |
| `macbook-pro-m2` | nix-darwin workstation, T3 Code server |
| `matt-desktop` | NixOS/COSMIC workstation, T3 Code server, Restic receiver |
| `oracle-0` | Oracle ARM VPS: Caddy, Cloudflare Tunnel, Vaultwarden, repertoire-builder, Grafana |

## Layout

- `flake.nix`: inputs, host wiring, package overlay, deploy-rs nodes
- `hosts/<host>/`: host configuration
- `modules/nixos/`: NixOS baseline shared by desktop and Oracle (nix, Tailscale, sudo)
- `modules/home/`: Home Manager config shared by the Mac and desktop
- `packages/`: local packages (`nix build .#runebender`)
- `secrets/`: agenix secrets; recipients in `secrets/secrets.nix`, keys in `lib/keys.nix`
- `templates/`: project templates, used via `dev <language> [dir]`

## Mac bootstrap

1. Install [Determinate Nix](https://install.determinate.systems/determinate-pkg/stable/Universal).
2. `sudo scutil --set ComputerName macbook-pro-m2 && sudo scutil --set LocalHostName macbook-pro-m2`
3. `git clone git@github.com:mcernohorsky/nix-config.git ~/.config/nix-config`
4. `nix develop -c just deploy-mac`

See [DEPLOYMENT.md](DEPLOYMENT.md) for deployment, recovery, and operations.
