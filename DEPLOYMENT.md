# Deployment and operations

All commands are `just` recipes, run inside `nix develop` (or `nix develop -c just <recipe>`).
Tailscale is the only management network. Oracle's public SSH port is closed.

```bash
just update [inputs...]  # all inputs, or named ones (e.g. repertoire-builder)
just deploy-oracle       # Mac: Determinate native Linux builder; desktop: binfmt
just deploy-desktop      # remote deploy-rs from the Mac, nixos-rebuild locally
just deploy-mac          # local on the Mac, over SSH from the desktop
just deploy-all
```

`deploy-desktop` reports whether a reboot is needed (kernel change or failed `nvidia-smi`).
deploy-rs `magicRollback` is off because activation restarts networking on the only SSH path.
Verify Oracle deploys with `just verify-chess`.

## Version control and workstation sync

Both workstations share one jj `main` bookmark (colocated with Git for Nix and GitHub).

```bash
jj commit -m 'Describe the change'
jj bookmark set main -r @-
nix develop -c just sync    # push main and update the other workstation
```

`sync` refuses to run if either host has unpublished work; commit and combine it first.
`just sync-check` runs the checks only. To pull changes from an empty working copy:
`jj git fetch --remote origin && jj new main`.

## Oracle services

- **repertoire-builder**: NixOS container `repertoire-builder` (PocketBase on private
  port 8090, data in `/var/lib/containers/repertoire-builder-v2`). Caddy publishes
  <https://chess.cernohorsky.ca>. Use `just container-{status,logs,restart}` and
  `just ssh-container`. If the frontend is stale, check the input revision with
  `nix flake metadata` and run `just update repertoire-builder`. Never bump versions
  to defeat caching.
- **groundwork**: NixOS container `groundwork` (port 7171), published at
  <https://groundwork.cernohorsky.ca>. Data in `/var/lib/containers/groundwork`: back up
  `state/`; `data/` is refetchable map data. `just groundwork-logs` shows a new server's
  setup code; `just groundwork-recover` logs a one-day owner sign-in code.
- **Vaultwarden**: <https://vault.cernohorsky.ca> through the Cloudflare Tunnel.
- **Grafana**: <https://metrics.cernohorsky.ca>.
- **Backups**: every six hours, Restic backs up verified SQLite copies of Vaultwarden,
  chess and Groundwork to R2 (`oracle-0-backups`, pruned on Oracle) and to the append-only
  REST server `rest:http://matt-desktop.tailc41cf5.ts.net:8000/` (pruned weekly on the
  desktop).

### Restore Vaultwarden

```bash
ssh matt@oracle-0
sudo -i
systemctl stop 'restic-backups-vaultwarden-*.timer' 'restic-backups-vaultwarden-*.service' vaultwarden
# R2; for the desktop repository, use its rest: URL and skip the AWS exports.
export AWS_ACCESS_KEY_ID=$(sed -n 's/^AWS_ACCESS_KEY_ID=//p' /run/agenix/restic-r2-credentials)
export AWS_SECRET_ACCESS_KEY=$(sed -n 's/^AWS_SECRET_ACCESS_KEY=//p' /run/agenix/restic-r2-credentials)
export RESTIC_PASSWORD_FILE=/run/agenix/restic-password
export RESTIC_REPOSITORY=s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups
restic snapshots --tag vaultwarden
restic restore latest --tag vaultwarden --target /

cd /var/lib/vaultwarden
test "$(sqlite3 db-backup.sqlite3 'PRAGMA integrity_check;')" = ok
rm -f db.sqlite3-wal db.sqlite3-shm
install -o vaultwarden -g vaultwarden -m 0600 db-backup.sqlite3 db.sqlite3
systemctl start vaultwarden restic-backups-vaultwarden-r2.timer restic-backups-vaultwarden-desktop.timer
```

Chess restores work the same way with `--tag chess`. Stop the container first, then
promote `data/db-backup.sqlite3` to `data/repertoire.sqlite3`.

## Security model

- Oracle accepts public traffic only on Tailscale UDP 41641 and ICMP. HTTP arrives through
  the outbound-only Cloudflare Tunnel, and Caddy binds to loopback.
- `tailscale-acl.json` isolates `tag:cloud` (Oracle), which can reach only the desktop's
  Restic port. Use `just tailscale-policy [show|diff|apply]` to manage it.
- The NixOS hosts use Tailscale SSH (`tailscale ssh` in automation). The Mac serves Apple
  OpenSSH, because tailnet SSH rules cannot target an untagged user device. The desktop
  reaches the Mac with matt's key from agenix (`ssh-id-ed25519`).
- Secrets are decrypted into `/run/agenix` at activation and never enter the store. After a
  host key changes, update `lib/keys.nix` and run `cd secrets && agenix -r -i ~/.ssh/id_ed25519`.

## Rebuild `oracle-0`

1. Create an ARM `VM.Standard.A1.Flex` Ubuntu VPS with temporary public SSH.
2. Put its host key (`ssh-keyscan <ip> | rg ed25519`) in `lib/keys.nix` and rekey the secrets.
3. `nixos-anywhere --flake .#oracle-0 root@<ip>` (disko: `/dev/sda`, 512 MiB ESP and ext4 root).
   If that fails, run disko manually and then `nixos-install --flake .#oracle-0`.
4. Verify `ssh matt@oracle-0` over Tailscale, remove public SSH, then check
   `systemctl status cloudflared-tunnel` and `curl -fsS https://chess.cernohorsky.ca`.

## Troubleshooting

- **Native Linux builder**: `determinate-nixd status`, `determinate-nixd auth login`,
  `sudo launchctl kickstart -k system/systems.determinate.nix-daemon`.
- **Changed host key**: `ssh-keygen -R <host>` and then `ssh-keyscan -H <host> >> ~/.ssh/known_hosts`.

## Workstation tools

Home Manager bootstraps Claude Code, Codex CLI, OpenCode, and T3 Code into `~/.local/bin`
and `~/.bun/bin`; they update themselves afterwards. On each new host:

1. Sign in once: `claude auth login`, `codex login`, `opencode auth login`.
2. Pair T3 clients with `t3 pair --tailscale`. Pairing links are credentials; keep them out
   of Git and logs.
3. In the T3 desktop app, keep **Settings → Connections → Local environment** off and add
   both `https://<host>.tailc41cf5.ts.net/` URLs (including the Mac's own) as **Remote link**
   environments.
4. For push notifications only (access stays on Tailscale), run
   `t3 connect link --publish-only` (`--headless` over SSH), then `t3 service restart`.

`just t3-status` checks both T3 services. `just t3-update` and `just opencode-update` update
both workstations and restart their servers, interrupting active turns.

## Desktop BIOS reference

Ryzen 7 5700X3D, ASUS ROG STRIX B450-F (BIOS 5901), 64 GiB DDR4, RTX 4080. Stable settings:
DDR4-3200, FCLK 1600, DRAM 1.365 V, SoC 1.10 V, timings 16-20-20-20-38 2T, PBO on, CSM off,
Above 4G and ReBAR on, Fast Boot off. After a failed memory change, power off fully and fall
back to these values.
