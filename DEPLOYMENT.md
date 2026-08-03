# Deployment Guide

This repository deploys three Nix hosts:

| Host | Role | Management path |
| --- | --- | --- |
| `oracle-0` | Oracle ARM VPS, Caddy, Cloudflare Tunnel, Vaultwarden, repertoire-builder | Tailscale SSH/deploy-rs |
| `matt-desktop` | NixOS workstation, OpenCode server, Restic receiver | Tailscale SSH/deploy-rs |
| `macbook-pro-m2` | nix-darwin workstation and remote OpenCode client | local `darwin-rebuild` |

All routine deployment commands are `just` recipes from the flake development
shell. Tailscale is the intended management network; Oracle's public SSH port
is closed after bootstrap.

## Routine deployment

Prerequisites: Tailscale connectivity, access to the agenix SSH identity, and
Determinate's native Linux builder authentication for Oracle builds.

```bash
nix develop
just update                 # update all inputs when desired
just update-app             # update only repertoire-builder
just deploy-oracle
just deploy-desktop         # reports whether a reboot is advisable
just deploy-mac
```

Non-interactive equivalents are `nix develop -c just <recipe>`. Use
`just deploy-all` only when deploying all three hosts together. Do not use
OrbStack as a deployment backend.

After `just deploy-desktop`, reboot only when its post-deploy check reports a
kernel change or an unavailable NVIDIA stack. Tailscale/SSH should remain
available even when NVIDIA needs a reboot.

## Repertoire-builder

The application runs in a native NixOS container on `oracle-0`; the container
serves PocketBase on private port `8090`. Host Caddy publishes it at:

- App: <https://chess.cernohorsky.ca>
- PocketBase admin: <https://chess.cernohorsky.ca/_/>
- Host health check: `curl http://repertoire-builder:8090/api/health`

Useful commands:

```bash
just verify-chess
just container-status oracle-0
just container-logs oracle-0
just container-restart oracle-0
just ssh-container oracle-0
```

The container data directory is
`/var/lib/containers/repertoire-builder/data`; the application user is
`pocketbase`. The host does not expose a separate public `:8090` listener.

After a deploy, `just verify-chess` checks `/api/version` and `/version.json`.
If the frontend appears stale, verify the `repertoire-builder` flake revision
with `nix flake metadata`; update it with `just update-app`. Do not change
version numbers or derivation inputs to defeat Nix caching.

### bun2nix EPERM

If a `web-dist` build fails linking packages across `/tmp` and `/build`, keep
the application flake's explicit string override:

```nix
bunInstallFlags = "--linker=isolated --backend=copyfile";
```

`BUN_CONFIG_INSTALL_BACKEND` does not override bun2nix's hook. Use
`bunInstallFlags` (a string, not a list).

## Vaultwarden and backups

Vaultwarden is published through the Cloudflare Tunnel at
`https://vault.cernohorsky.ca`. Backups run every six hours to:

1. Cloudflare R2 (`oracle-0-backups`), with GFS pruning on Oracle.
2. The append-only Restic REST server on `matt-desktop` at
   `rest:http://matt-desktop.tailc41cf5.ts.net:8000/`, pruned locally on the
   desktop.

The encrypted secrets are `vaultwarden-admin-token.age`, `restic-password.age`,
and `restic-r2-credentials.age`. Agenix decrypts them only at activation; do
not put plaintext credentials in Nix expressions or the repository.

### Restore Vaultwarden

Stop the service and both backup pipelines before restoring:

```bash
ssh matt@oracle-0 <<'EOF'
sudo systemctl stop \
  restic-backups-vaultwarden-r2.timer \
  restic-backups-vaultwarden-desktop.timer \
  restic-backups-vaultwarden-r2.service \
  restic-backups-vaultwarden-desktop.service \
  vaultwarden
EOF
```

Restore from R2:

```bash
ssh matt@oracle-0
sudo -i
export AWS_ACCESS_KEY_ID=$(sed -n 's/^AWS_ACCESS_KEY_ID=//p' /run/agenix/restic-r2-credentials)
export AWS_SECRET_ACCESS_KEY=$(sed -n 's/^AWS_SECRET_ACCESS_KEY=//p' /run/agenix/restic-r2-credentials)
export RESTIC_PASSWORD_FILE=/run/agenix/restic-password
export RESTIC_REPOSITORY="s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups"
restic snapshots
restic restore latest --target /
test -s /var/lib/vaultwarden/db-backup.sqlite3
test "$(sqlite3 /var/lib/vaultwarden/db-backup.sqlite3 'PRAGMA integrity_check;')" = ok
rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
install -o vaultwarden -g vaultwarden -m 0600 \
  /var/lib/vaultwarden/db-backup.sqlite3 /var/lib/vaultwarden/db.sqlite3
```

If R2 is unavailable, use the desktop repository instead:

```bash
export RESTIC_REPOSITORY="rest:http://matt-desktop.tailc41cf5.ts.net:8000/"
export RESTIC_PASSWORD_FILE=/run/agenix/restic-password
restic snapshots
restic restore latest --target /
```

Run the same integrity check and database promotion above, then restart the
service and timers only after validation:

```bash
systemctl start vaultwarden
systemctl is-active --quiet vaultwarden
systemctl start restic-backups-vaultwarden-r2.timer restic-backups-vaultwarden-desktop.timer
```

## Security and Tailscale

- Oracle public ingress is blocked except Tailscale direct-connect UDP `41641`
  and required ICMP.
- Oracle uses Tailscale SSH; `services.openssh.enable = false`.
- Desktop OpenSSH remains available without a public firewall opening for
  deploy-rs compatibility.
- Cloudflare Tunnel is outbound-only.
- `tailscale-acl.json` isolates `tag:cloud` (Oracle) from trusted devices.
- Taildrive shares are configured declaratively; Oracle shares `/` and the
  desktop shares `/` and `/mnt/hdd`.

Apply ACL changes in the Tailscale admin console, then verify connectivity:

```bash
nix develop -c just tailscale-status
nix develop -c just ping-all
```

If rebuilding Oracle, keep SSH port 22 open only during bootstrap and remove it
after Tailscale is working.

## Disaster recovery: rebuild `oracle-0`

1. Create an ARM `VM.Standard.A1.Flex` VPS with Ubuntu and temporary SSH port
   22 access.
2. Get the new host key and replace `oracle-0` in `secrets/secrets.nix`:

   ```bash
   ssh-keyscan <new-ip> 2>/dev/null | rg ed25519
   ```

3. Rekey the encrypted secrets:

   ```bash
   cd secrets
   agenix -r -i ~/.ssh/id_ed25519
   cd ..
   ```

4. Install with disko/nixos-anywhere:

   ```bash
   nixos-anywhere --flake .#oracle-0 root@<new-ip>
   ```

   `hosts/oracle-0/disk-config.nix` uses `/dev/sda`: a 512 MiB EFI partition
   and an ext4 root partition using the remainder.

5. Wait for the reboot, verify `ssh matt@oracle-0` over Tailscale, remove
   public SSH ingress, then check:

   ```bash
   ssh matt@oracle-0 sudo systemctl status cloudflared-tunnel
   curl -fsS https://cernohorsky.ca
   curl -fsS https://chess.cernohorsky.ca
   ```

If nixos-anywhere fails, boot the installer manually, run disko against
`hosts/oracle-0/disk-config.nix`, and install with
`nixos-install --flake .#oracle-0`.

## Troubleshooting

### Native Linux builder

Oracle builds use Determinate's native Linux builder, not Docker or OrbStack:

```bash
determinate-nixd status
determinate-nixd auth login
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

### Tailscale/OpenSSH transition

If activation reports `sshd.service` missing after disabling OpenSSH, reboot
Oracle once so `/run/booted-system` reflects the new configuration:

```bash
ssh matt@oracle-0 sudo reboot
```

### Caddy returns 502

If Caddy exhausted systemd's start limit, temporarily start it with
`ssh matt@oracle-0 sudo systemctl start caddy`; the declarative fix is:

```nix
systemd.services.caddy.unitConfig.StartLimitIntervalSec = 0;
```

### Deployment timeout or host-key failure

Deploy-rs normally rolls back after a Tailscale interruption. For a changed
host key:

```bash
ssh-keygen -R oracle-0.tailc41cf5.ts.net
ssh-keyscan -H oracle-0.tailc41cf5.ts.net >> ~/.ssh/known_hosts
```

## Desktop BIOS reference

Hardware: Ryzen 7 5700X3D, ASUS ROG STRIX B450-F, 64 GiB DDR4-3200,
RTX 2070. Stable settings (BIOS 5901): manual memory, DDR4-3200, FCLK 1600,
DRAM 1.365 V, SoC 1.10 V, timings `16-20-20-20-38`, command rate 2T, PBO
enabled, CSM disabled, Above 4G decoding and ReBAR enabled, Fast Boot disabled.

After a failed memory change, power off fully and reboot into safe recovery;
then reduce memory settings or return to the last known-good values.

## OpenCode v2 beta

OpenCode uses the official `@opencode-ai/cli@next` Bun package on both agent
hosts. `oc` launches locally; `ocd` connects the MacBook CLI to the desktop at
`https://matt-desktop.tailc41cf5.ts.net` through Tailscale.

The desktop API is systemd-owned at `127.0.0.1:4097`, published only through
Tailscale Serve, and protected by HTTP Basic Auth. The shared password is the
agenix secret `opencode-server-password.age`. Provider credentials, models,
subagents, sessions, plugins, and MCPs intentionally start empty.

```bash
nix develop -c just opencode-update
nix develop -c just desktop-opencode-status
nix develop -c just desktop-opencode-logs
nix develop -c just desktop-opencode-restart
nix develop -c just desktop-opencode-reset-serve
```

The Mac desktop beta DMG and Linux AppImage are writable, outside the Nix
store, and follow their official update mechanisms. The v2 preview CLI does
not expose the mainline browser `web` command; its tailnet endpoint is API-only
for now. Do not add a legacy web backend or third-party phone app. Revisit the
official browser UI when it lands in v2.

## Claude Code

Claude Code uses Anthropic's native `latest` installer on both agent hosts;
native installs update in the background:

```bash
curl -fsSL https://claude.ai/install.sh | bash -s latest
claude update                 # optional immediate update
```

The binary is `~/.local/bin/claude`. Claude configuration and authentication
are local to each machine and are not stored in Nix.

## Agenix rule

Secrets in `secrets/*.age` are encrypted for the required user/host SSH keys.
Activation decrypts them into `/run/agenix`; plaintext secret values do not
enter the Nix store. When a host key changes, update `secrets/secrets.nix` and
run `agenix -r -i ~/.ssh/id_ed25519`.
