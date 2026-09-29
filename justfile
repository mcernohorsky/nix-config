oracle_host := "oracle-0.tailc41cf5.ts.net"
desktop_host := "matt-desktop.tailc41cf5.ts.net"
mac_host := "macbook-pro-m2.tailc41cf5.ts.net"
desktop_ssh := "tailscale ssh matt@" + desktop_host
chess_url := "https://chess.cernohorsky.ca"

default:
    @just --list

# Update all flake inputs, or only the named ones (e.g. `just update hex hex-homebrew-tap`)
update *inputs:
    nix flake update {{ inputs }}

# Update the Sonora Homebrew tap (including its pinned cask version)
update-sonora:
    nix flake update sonora-homebrew-tap

build-oracle:
    nix build .#nixosConfigurations.oracle-0.config.system.build.toplevel

# Builds on the Mac's native Linux builder or the desktop's binfmt emulation
deploy-oracle:
    nix run .#deploy-rs -- .#oracle-0 --skip-checks

[macos]
deploy-desktop:
    nix run .#deploy-rs -- .#matt-desktop --skip-checks
    @{{ desktop_ssh }} '{{ reboot_check }}'

[linux]
deploy-desktop:
    sudo nixos-rebuild switch --flake .#matt-desktop
    @{{ reboot_check }}

[macos]
deploy-mac:
    sudo env NIX_CONFIG='accept-flake-config = true' darwin-rebuild switch --flake .

[linux]
deploy-mac:
    ssh -t matt@{{ mac_host }} 'cd ~/.config/nix-config && nix develop -c just deploy-mac'

[parallel]
deploy-all: deploy-oracle deploy-desktop deploy-mac

reboot_check := 'if [ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f /run/current-system/kernel)" ] || ! nvidia-smi >/dev/null 2>&1; then echo "⚠️  Kernel changed or NVIDIA is unavailable; reboot matt-desktop"; else echo "✅ No reboot needed"; fi'

ssh host=oracle_host:
    ssh matt@{{ host }}

container-status:
    ssh matt@{{ oracle_host }} sudo machinectl list

container-logs:
    ssh matt@{{ oracle_host }} sudo journalctl -M repertoire-builder -f

container-restart:
    ssh matt@{{ oracle_host }} sudo machinectl restart repertoire-builder

ssh-container:
    ssh -t matt@{{ oracle_host }} sudo machinectl shell repertoire-builder

# Backend and frontend versions of the deployed chess app
verify-chess:
    curl -fsSL {{ chess_url }}/api/version | jq .
    curl -fsSL {{ chess_url }}/version.json | jq .

# Exit non-zero if any host is unreachable
ping-all:
    #!/usr/bin/env bash
    fail=0
    for host in {{ oracle_host }} {{ desktop_host }} {{ mac_host }}; do
      ping -c 1 "$host" >/dev/null && echo "✅ $host" || { echo "❌ $host" >&2; fail=1; }
    done
    exit $fail

t3-status:
    ssh matt@{{ mac_host }} '"$HOME/.local/bin/t3" service status'
    {{ desktop_ssh }} '"$HOME/.local/bin/t3" service status'

# Update both T3 services and repair launcher state left by older updaters
t3-update: t3-update-mac t3-update-desktop

[macos]
t3-update-mac:
    PATH="$HOME/.local/bin:$HOME/.bun/bin:/etc/profiles/per-user/matt/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" "$HOME/.local/bin/t3" update --channel stable --yes
    PATH="$HOME/.local/bin:$HOME/.bun/bin:/etc/profiles/per-user/matt/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" "$HOME/.local/bin/t3" service install

[linux]
t3-update-mac:
    ssh matt@{{ mac_host }} 'cd ~/.config/nix-config && nix develop -c just t3-update-mac'

t3-update-desktop:
    {{ desktop_ssh }} 'export PATH="$HOME/.local/bin:$HOME/.bun/bin:/etc/profiles/per-user/matt/bin:/run/current-system/sw/bin:/usr/bin:/bin"; "$HOME/.local/bin/t3" update --channel stable --yes && systemctl --user reset-failed t3code.service && "$HOME/.local/bin/t3" service install'

# Pairing links are one-time credentials; generate them only when adding a device
t3-pair-mac:
    ssh matt@{{ mac_host }} '"$HOME/.local/bin/t3" pair --tailscale'

t3-pair-desktop:
    {{ desktop_ssh }} '"$HOME/.local/bin/t3" pair --tailscale'

# Tailnet policy: show | diff | apply (apply prompts for YES, guarded by the live ETag)
tailscale-policy action="diff":
    tailscale-policy {{ action }} {{ if action == "show" { "" } else { "tailscale-acl.json" } }}
