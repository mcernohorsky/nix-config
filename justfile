oracle_host := "oracle-0.tailc41cf5.ts.net"
desktop_host := "matt-desktop.tailc41cf5.ts.net"
mac_host := "macbook-pro-m2.tailc41cf5.ts.net"
desktop_ssh := "tailscale ssh matt@" + desktop_host
# T3 snapshots PATH when it installs its service; use the same stable set here
t3_path := "$HOME/.local/bin:$HOME/.bun/bin:/etc/profiles/per-user/matt/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

default:
    @just --list

# Publish main and synchronize the other workstation without discarding work
sync:
    bash scripts/sync-workstations.sh

# Check both workstations for unpublished work without pushing
sync-check:
    bash scripts/sync-workstations.sh --check

# Update all flake inputs, or only the named ones (e.g. `just update hex hex-homebrew-tap`)
update *inputs:
    nix flake update {{ inputs }}

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

container-status:
    ssh matt@{{ oracle_host }} sudo machinectl list

container-logs name:
    ssh matt@{{ oracle_host }} sudo journalctl -M {{ name }} -f

groundwork-logs:
    ssh matt@{{ oracle_host }} sudo journalctl -M groundwork -u groundwork -u groundwork-geodata -f

# A one-day owner sign-in code in the log, for when no one can sign in.
groundwork-recover:
    ssh matt@{{ oracle_host }} 'sudo touch /var/lib/containers/groundwork/state/tenants/main/recover && sudo machinectl restart groundwork'

container-restart name:
    ssh matt@{{ oracle_host }} sudo machinectl restart {{ name }}

ssh-container name:
    ssh -t matt@{{ oracle_host }} sudo machinectl shell {{ name }}

# Report the T3 service version and unit on both workstations
[macos]
t3-status:
    PATH="{{ t3_path }}" "$HOME/.local/bin/t3" service status
    {{ desktop_ssh }} '"$HOME/.local/bin/t3" service status'

[linux]
t3-status:
    ssh matt@{{ mac_host }} '"$HOME/.local/bin/t3" service status'
    "$HOME/.local/bin/t3" service status

# Update both T3 services and repair launcher state left by older updaters
t3-update: t3-update-mac t3-update-desktop

[macos]
t3-update-mac:
    PATH="{{ t3_path }}" "$HOME/.local/bin/t3" update --channel nightly --yes
    PATH="{{ t3_path }}" "$HOME/.local/bin/t3" service install

[linux]
t3-update-mac:
    ssh matt@{{ mac_host }} 'cd ~/.config/nix-config && nix develop -c just t3-update-mac'

t3-update-desktop:
    {{ desktop_ssh }} 'export PATH="{{ t3_path }}"; "$HOME/.local/bin/t3" update --channel nightly --yes && systemctl --user reset-failed t3code.service && "$HOME/.local/bin/t3" service install'

# Update OpenCode's Bun install and stop T3's stale per-session servers
opencode-update: opencode-update-mac opencode-update-desktop

[macos]
opencode-update-mac: opencode-update-local

[linux]
opencode-update-mac:
    ssh matt@{{ mac_host }} 'cd ~/.config/nix-config && nix develop -c just opencode-update-mac'

opencode-update-desktop:
    {{ desktop_ssh }} 'cd ~/.config/nix-config && nix develop -c just opencode-update-local'

opencode-update-local:
    "$HOME/.bun/bin/opencode" upgrade --method bun
    # T3 Code's per-session servers outlive T3 restarts as orphans of PID 1
    -pkill -P 1 -f 'opencode serve --hostname='

# Tailnet policy: show | diff | apply (apply prompts for YES, guarded by the live ETag)
tailscale-policy action="diff":
    tailscale-policy {{ action }} {{ if action == "show" { "" } else { "tailscale-acl.json" } }}
