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

# Build on oracle-0 (default), mac or desktop
deploy-oracle builder="oracle":
    bash scripts/deploy-oracle.sh {{ builder }}

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

# Update T3 (service and Mac app) plus Claude, Codex and OpenCode on both workstations
upgrade:
    bash scripts/upgrade-workstations.sh

# Prints a credential QR/link to the caller's terminal; never capture it in logs.
t3-pair-full host:
    bash scripts/t3-pair-full.sh {{ host }}

# Tailnet policy: show | diff | apply (apply prompts for YES, guarded by the live ETag)
tailscale-policy action="diff":
    tailscale-policy {{ action }} {{ if action == "show" { "" } else { "tailscale-acl.json" } }}
