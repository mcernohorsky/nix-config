# Decisions — jellyfin-x9-pro-transfer

## Scope
- Prep ONLY: no transfers to matt-desktop, no /mnt/hdd writes
- Move/rename only: no file copies
- Do NOT touch: Marty Supreme, Peaky Blinders, The Penguin, or any already-transferred title

## Staging Architecture
- Ready tree: /Volumes/x9-pro/Jellyfin Ready/  (user-facing drag/drop root)
- Sidecar archive: /Volumes/x9-pro/_jellyfin-prep-sidecars/YYYY-MM-DD-prep/  (non-media junk)
- Evidence: .sisyphus/evidence/task-{N}-{slug}.txt

## Episode-Numbering Policy (From S01)
- E01-E07: from UIndex subfolders in /Volumes/x9-pro/Shows/From/
- E08: the Italian-titled loose file From.S01E08.Finestre.rotte.porte.aperte...mkv → rename to From - S01E08.mkv
- E09-E10: remaining UIndex subfolders
