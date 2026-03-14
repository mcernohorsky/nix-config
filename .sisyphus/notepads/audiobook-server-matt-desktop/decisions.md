# Decisions — audiobook-server-matt-desktop

## 2026-03-14 Session start
- Port 13378 chosen (not 8000 which conflicts with Restic)
- openFirewall = false; exposure managed via networking.firewall.interfaces."tailscale0" 
- audiobookshelf user stays default; gets users group for NTFS access (gid=100)
- systemd.tmpfiles.rules creates /mnt/hdd/audiobooks (owner: matt, group: users, mode: 0755)
- RequiresMountsFor prevents startup race with NTFS HDD mount
- No commit until Task 6 (single commit at end: feat(matt-desktop): add audiobookshelf server)
