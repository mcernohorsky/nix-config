# Learnings — audiobook-server-matt-desktop

## 2026-03-14 Session start
- Worktree: /private/tmp/nix-config-audiobook-server-matt-desktop (branch: audiobook-server-matt-desktop)
- Main repo: /Users/matt/.config/nix-config
- Target files: hosts/matt-desktop/modules/media.nix, hosts/matt-desktop/configuration.nix
- Audiobookshelf port: 13378
- Library path: /mnt/hdd/audiobooks (NTFS, uid=1000 gid=100/users)
- State/metadata path: /var/lib/audiobookshelf (module default, SSD)
- Service user: audiobookshelf (default)
- Exposure: tailscale0 only (direct port access, no reverse proxy)
- Tailscale hostname: matt-desktop.tailc41cf5.ts.net
- Existing tailscale0 firewall port: 8000 (Restic, must be preserved)
- All edits happen in the worktree, not the main repo
