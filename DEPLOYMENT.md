# Deployment Guide

This repository deploys three Nix hosts:

| Host | Role | Management path |
| --- | --- | --- |
| `oracle-0` | Oracle ARM VPS, Caddy, Cloudflare Tunnel, Vaultwarden, repertoire-builder | Tailscale SSH/deploy-rs |
| `matt-desktop` | NixOS workstation, T3 Code server, Restic receiver | Tailscale SSH/deploy-rs |
| `macbook-pro-m2` | nix-darwin workstation and T3 Code server | local `darwin-rebuild` |

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
just deploy-desktop         # from the Mac: build remote, reports reboot advice
just deploy-local           # from either machine: rebuilds the local host
```

Non-interactive equivalents are `nix develop -c just <recipe>`. Use
`just deploy-all` only when deploying all three hosts together. Do not use
OrbStack as a deployment backend.

After `just deploy-desktop`, reboot only when its post-deploy check reports a
kernel change or an unavailable NVIDIA stack. The deploying agent is
authorized to run that reboot itself (`ssh matt@matt-desktop.tailc41cf5.ts.net
sudo reboot`). Tailscale/SSH should remain
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

Restore from R2 (if R2 is unavailable, substitute the desktop repository
`rest:http://matt-desktop.tailc41cf5.ts.net:8000/` and skip the `AWS_*`
exports):

```bash
ssh matt@oracle-0
sudo -i
export AWS_ACCESS_KEY_ID=$(sed -n 's/^AWS_ACCESS_KEY_ID=//p' /run/agenix/restic-r2-credentials)
export AWS_SECRET_ACCESS_KEY=$(sed -n 's/^AWS_SECRET_ACCESS_KEY=//p' /run/agenix/restic-r2-credentials)
export RESTIC_PASSWORD_FILE=/run/agenix/restic-password
export RESTIC_REPOSITORY="s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups"
restic snapshots
restic restore latest --target /
```

Validate the restored backup and promote it, then restart the service and
timers only after validation:

```bash
test -s /var/lib/vaultwarden/db-backup.sqlite3
test "$(sqlite3 /var/lib/vaultwarden/db-backup.sqlite3 'PRAGMA integrity_check;')" = ok
rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
install -o vaultwarden -g vaultwarden -m 0600 \
  /var/lib/vaultwarden/db-backup.sqlite3 /var/lib/vaultwarden/db.sqlite3
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
- All SSH targets are tailnet MagicDNS names. Automation (the `just` desktop
  recipes and agent reboots) uses `tailscale ssh` where the
  tailnet ssh policy applies, and plain `ssh` toward the Mac, which serves
  Apple OpenSSH because the policy cannot address user-owned devices;
  interactive logins may use plain `ssh` anywhere.
- Desktop-to-Mac SSH authenticates with matt's personal key (agenix
  `ssh-id-ed25519`, installed `0600` by activation); the Mac authorizes it
  via nix-darwin and pins Apple's host keys with accept-new. Mac Remote
  Login stays on for this.
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

`magicRollback` is disabled on both deploy-rs nodes: activation restarts
networking while Tailscale is the only SSH path, so deploy-rs cannot confirm
the switch even when it succeeds. Verify manually with `just verify-chess`
after each deploy. For a changed host key:

```bash
ssh-keygen -R oracle-0.tailc41cf5.ts.net
ssh-keyscan -H oracle-0.tailc41cf5.ts.net >> ~/.ssh/known_hosts
```

## Desktop BIOS reference

Hardware: Ryzen 7 5700X3D, ASUS ROG STRIX B450-F, 64 GiB DDR4-3200,
RTX 4080. Stable settings (BIOS 5901): manual memory, DDR4-3200, FCLK 1600,
DRAM 1.365 V, SoC 1.10 V, timings `16-20-20-20-38`, command rate 2T, PBO
enabled, CSM disabled, Above 4G decoding and ReBAR enabled, Fast Boot disabled.

After a failed memory change, power off fully and reboot into safe recovery;
then reduce memory settings or return to the last known-good values.

## OpenCode v2

OpenCode uses the official `@opencode/cli` Bun package (stable, binary
`opencode`) on both agent hosts. `oc` launches locally. The stable package also ships an `opencode2`
compat shim; the beta-era `@opencode-ai/cli@beta` package is removed by Home
Manager activation.

OpenCode's Go subscription is authenticated through `opencode auth login` on
each host. T3 Code reads the local OpenCode config and starts its local
provider helper; OpenCode no longer has a remote service or Tailscale mapping.
`autoupdate = true` remains enabled in `opencode.json`.

The Mac desktop DMG and Linux AppImage (`~/.local/opt/opencode/`) are writable,
outside the Nix store, and follow their official update mechanisms.

## T3 Code

The Mac desktop app is a declarative Homebrew cask (`t3-code`). Home Manager
bootstraps the official writable `t3` CLI on both hosts, then installs its
native per-user background service. T3 owns its service unit
and versioned runtime so the web/mobile UI and `t3 update` can update it
without a Nix deployment. The Mac service runs while matt is logged in and
the machine is awake; the desktop service runs from boot through systemd
lingering. T3's service PATH includes `~/.local/bin` for Claude Code,
`~/.bun/bin` for Codex CLI and OpenCode, and the stable Nix profiles.
Home Manager sets the Mac app to client mode before first launch so it does not
start a second server against the service's database. Pair the app with the Mac
service through its Tailscale HTTPS address.

T3 is the only remote coding endpoint. Both hosts expose their own T3 server
through Tailscale Serve HTTPS on port 443, after one `t3 pair --tailscale`
per host. The tailnet URLs are:

- `https://macbook-pro-m2.tailc41cf5.ts.net/`
- `https://matt-desktop.tailc41cf5.ts.net/`

The T3 iOS/iPadOS app, T3 desktop clients, or `app.t3.codes` can add each
environment using a fresh pairing link. Do not put pairing links in Git or
logs. The client can select the Mac now and the desktop later; provider
credentials, threads, and projects live on the chosen host. Keep the same
project checked out on both machines if both should work on it. Tailscale's
ACL already allows matt's phone, iPad, Mac, and desktop to reach the two hosts.

```bash
nix develop -c just t3-status
nix develop -c just t3-pair-mac
nix develop -c just t3-pair-desktop
```

Open Settings → Providers on each T3 environment and enable Codex, Claude
Code, and OpenCode. Sign in to each CLI on the host if needed (`codex login`,
`claude auth login`, `opencode auth login`); T3 then uses the existing local
credentials. T3 0.0.42's OpenCode provider only works with OpenCode v1: it waits
for `opencode serve` to print `opencode server listening`, but v2 prints
`server listening on ...`, so the probe times out after 30s. Both hosts
currently have OpenCode v2 (auto-updated past v1), so the T3 OpenCode provider
stays unavailable until upstream T3 supports v2; use `oc` directly for
OpenCode in the meantime. Do not downgrade to v1: `autoupdate = true` would
pull v2 back. T3's provider status can
update Bun-installed Codex CLI and OpenCode. Server updates can interrupt
active turns, so use T3's update prompt when the host is idle. Enable
Settings → General → Continue threads after restarts if desired.

To retire the former OpenCode Serve endpoint on a host, run
`tailscale serve --https=443 off` before `t3 pair --tailscale`. The old
OpenCode service and sync units are no longer configured; do not reset all
Tailscale Serve mappings, which could remove unrelated routes.

## Claude

Home Manager bootstraps Claude Code through Anthropic's native `latest`
installer on the Mac and Linux desktop when `~/.local/bin/claude` is missing.
The binary remains outside the Nix store so native background updates work;
`claude update` can force an immediate update. Home Manager merges the selected
privacy and attribution settings into the writable `~/.claude/settings.json`
and installs a user-level Git rule. Authentication stays local to each machine.

The Mac installs Claude Desktop through the `claude` Homebrew cask and lets the
app update itself. Claude Desktop's Linux beta supports Debian and Ubuntu, not
NixOS, and does not update itself; it is not installed on matt-desktop.

`DISABLE_TELEMETRY=1` turns off Claude Code's telemetry and feature-flag
fetching, including Remote Control. For a consumer account, model-training
consent is separate: turn off **Help Improve our AI models** under Claude's
Settings → Privacy. Claude Desktop does not document an app-wide telemetry
switch.

## Agenix rule

Secrets in `secrets/*.age` are encrypted for the required user/host SSH keys.
Activation decrypts them into `/run/agenix`; plaintext secret values do not
enter the Nix store. When a host key changes, update `secrets/secrets.nix` and
run `agenix -r -i ~/.ssh/id_ed25519`.
