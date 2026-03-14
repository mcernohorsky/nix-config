# Learnings — jellyfin-x9-pro-transfer

## Jellyfin Naming Conventions (confirmed via live SSH to matt-desktop)
- **Movies**: `Title (Year) [tmdbid-ID]/Title (Year).ext`
  - Colons become ` - ` (hyphen with spaces): `Furiosa - A Mad Max Saga (2024) [tmdbid-786892]`
  - Example: `/mnt/hdd/Movies/Dunkirk (2017) [tmdbid-374720]/Dunkirk (2017).mkv`
- **Shows**: `Title (Year) [tvdbid-ID]/Season 01/Show Name - S01E##.ext`
  - Season folders are zero-padded: `Season 01`, NOT `Season 1`
  - Example: `/mnt/hdd/Shows/Deadwood (2004) [tvdbid-72023]/Season 01/Deadwood - S01E01.mkv`

## Target IDs
- 28 Years Later: The Bone Temple → tmdbid-1272837 (movie, 2026)
- The Pitt → tvdbid-448176 (show, 2025)
- A Knight of the Seven Kingdoms → tvdbid-433631 (show, 2026)
- From → tvdbid-401003 (show, 2022)

## Filesystem Constraint
- /Volumes/x9-pro has ~161G free; selected media is ~113G
- MUST move/rename in place — no copies

## Pre-flight Inventory Findings (2026-03-13)
- All 8 source paths exist on /Volumes/x9-pro
- Filesystem: Single APFS volume (/dev/disk7s1) with 161G free
- Total media files inventoried: 
  - Movie: 1 file (28 Years Later) = 20,804,790,244 bytes (~19.38 GiB)
  - The Pitt: 15 MKV episodes = ~25.5 GiB total
  - From: 1 loose MKV (E08) + 9 UIndex folders with MKVs = ~10+ GiB estimated
  - A Knight: 2 loose MKVs (E01, E05) + 3 UIndex folders (E02-E04) = ~10+ GiB estimated
- Key observations:
  - The Pitt contains nfo.screens.poster/ directory that should be excluded
  - From season has E08 as loose Italian-titled file, E01-E07/E09-E10 as UIndex folders
  - A Knight of the Seven Kingdoms split across 5 locations as expected
- No files were moved, copied, or renamed during inventory
Task 2 completed: Created directory structure under /Volumes/x9-pro/Jellyfin Ready and /Volumes/x9-pro/_jellyfin-prep-sidecars/2026-03-13-prep

Task 3 completed: moved+renamed 28 Years Later movie into Jellyfin Ready tree.
- Destination: /Volumes/x9-pro/Jellyfin Ready/Movies/28 Years Later - The Bone Temple (2026) [tmdbid-1272837]/28 Years Later - The Bone Temple (2026).mp4
- Verified size: 20804790244 bytes before/after move
- Removed now-empty source folder: /Volumes/x9-pro/Movies/28.Years.Later.The.Bone.Temple.2026.2160p.iT.WEB-DL.DV.HDR10+.DDP5.1.Atmos.H265.MP4-BEN.THE.MEN

Task 4 completed: staged The Pitt Season 01 (15 episodes) into Jellyfin Ready with canonical `The Pitt - S01E##.mkv` naming.
- Destination: /Volumes/x9-pro/Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/Season 01/
- Verified all 15 episode byte sizes match pre-move inventory values after move
- Moved sidecar metadata directory to: /Volumes/x9-pro/_jellyfin-prep-sidecars/2026-03-13-prep/Shows/The Pitt (2025) [tvdbid-448176]/nfo.screens.poster/
- Source folder removed via rmdir after relocating leftover .DS_Store to sidecar archive

Task 5 completed: staged A Knight of the Seven Kingdoms Season 01 (5 episodes) into Jellyfin Ready with canonical `A Knight of the Seven Kingdoms - S01E##.mkv` naming.
- Destination: /Volumes/x9-pro/Jellyfin Ready/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/Season 01/
- Verified all 5 episode byte sizes match pre-move values after move (E01 6115254972, E02 3640313255, E03 2274541402, E04 4797209696, E05 3128971659)
- Moved non-media sidecars from all 3 UIndex folders to: /Volumes/x9-pro/_jellyfin-prep-sidecars/2026-03-13-prep/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/
- Removed all 3 emptied UIndex source folders via rmdir
- GNU stat is active in this shell (`stat -c%s`); `stat -f "%z"` prints filesystem metadata instead of byte-only output

Task 6 completed: staged From (2022) Season 01 (10 episodes) into Jellyfin Ready with canonical `From - S01E##.mkv` naming.
- Destination: /Volumes/x9-pro/Jellyfin Ready/Shows/From (2022) [tvdbid-401003]/Season 01/
- Verified all 10 episode byte sizes after move (E01 5477791703, E02 4918523266, E03 5588234222, E04 4954445877, E05 4817726259, E06 4757778972, E07 5175314775, E08 5264855200, E09 4593740663, E10 4978570006)
- E08 loose Italian-titled source file moved and renamed to `From - S01E08.mkv` (title dropped)
- Moved non-media sidecars to: /Volumes/x9-pro/_jellyfin-prep-sidecars/2026-03-13-prep/Shows/From (2022) [tvdbid-401003]/
- Root source folder removal required relocating leftover .DS_Store to sidecar archive, then rmdir succeeded
- When consolidating sidecars from many folders into one flat archive folder, duplicate filenames (for example torrent `.txt`) overwrite unless renamed or per-episode subfolders are used
