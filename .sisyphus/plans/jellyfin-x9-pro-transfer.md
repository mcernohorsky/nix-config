# Jellyfin X9-Pro Prep

## TL;DR
> **Summary**: Prepare exactly four missing titles on `/Volumes/x9-pro` so they already match the live Jellyfin naming convention, but do not transfer anything to `matt-desktop` yet. Move and rename the selected media into a drag-and-drop-ready staging tree, and move sidecar junk into a separate archive outside that tree.
> **Deliverables**:
> - `/Volumes/x9-pro/Jellyfin Ready/Movies/28 Years Later - The Bone Temple (2026) [tmdbid-1272837]/28 Years Later - The Bone Temple (2026).mp4`
> - `/Volumes/x9-pro/Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/Season 01/...`
> - `/Volumes/x9-pro/Jellyfin Ready/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/Season 01/...`
> - `/Volumes/x9-pro/Jellyfin Ready/Shows/From (2022) [tvdbid-401003]/Season 01/...`
> - `/Volumes/x9-pro/_jellyfin-prep-sidecars/$(date +%F)-prep/` containing moved `.nfo`, torrent text, and other non-media leftovers
> - `.sisyphus/evidence/task-*-*.txt` manifest + verification evidence
> **Effort**: Short
> **Parallel**: YES - 3 waves
> **Critical Path**: 1 -> 2 -> (3,4,5,6) -> 7 -> 8

## Context
### Original Request
Compare `/Volumes/x9-pro` against Jellyfin, identify what is missing, then prepare the files and folders according to the Jellyfin server's practices.

### Interview Summary
- The live Jellyfin library on `matt-desktop` already contains overlapping titles like `Dunkirk`, `The Dark Knight`, the `Lord of the Rings` trilogy, `The Prestige`, `Curb Your Enthusiasm`, `Deadwood`, `Game of Thrones`, and `Mad Men`.
- The missing candidates were narrowed down, and the user selected only `The Pitt`, `28 Years Later: The Bone Temple`, `A Knight of the Seven Kingdoms`, and `From`.
- The user then changed scope: do **not** transfer anything to `matt-desktop` yet; only prepare the x9-pro files so later drag-and-drop will work cleanly.
- The user also clarified that moving and renaming x9-pro files is acceptable; no local duplicate copies are needed.

### Metis Review (gaps addressed)
- Removed all `/mnt/hdd` writes and Jellyfin DB polling from this prep-only plan.
- Switched from copy-based staging to move/rename-in-place because `/Volumes/x9-pro` has only ~161G free and the selected media totals ~113G.
- Added a dedicated ready tree (`/Volumes/x9-pro/Jellyfin Ready`) and a separate sidecar archive (`/Volumes/x9-pro/_jellyfin-prep-sidecars/...`) so later drag-and-drop does not bring junk files with it.
- Added exact per-title source-to-ready mappings, especially for the split `A Knight of the Seven Kingdoms` and mixed-source `From` season.
- Added a final manifest that maps current ready paths to the later drop targets on `matt-desktop`.

## Work Objectives
### Core Objective
Reorganize the selected x9-pro media into a clean local staging tree that exactly mirrors the current Jellyfin naming pattern, so the user can later drag the prepared title folders into `/mnt/hdd/Movies` or `/mnt/hdd/Shows` and Jellyfin will detect them correctly.

### Deliverables
- A staging root: `/Volumes/x9-pro/Jellyfin Ready/`
- A sidecar archive root: `/Volumes/x9-pro/_jellyfin-prep-sidecars/$(date +%F)-prep/`
- One staged movie title:
  - `/Volumes/x9-pro/Jellyfin Ready/Movies/28 Years Later - The Bone Temple (2026) [tmdbid-1272837]/28 Years Later - The Bone Temple (2026).mp4`
- Three staged show titles:
  - `/Volumes/x9-pro/Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/Season 01/The Pitt - S01E01.mkv` ... `S01E15.mkv`
  - `/Volumes/x9-pro/Jellyfin Ready/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/Season 01/A Knight of the Seven Kingdoms - S01E01.mkv` ... `S01E05.mkv`
  - `/Volumes/x9-pro/Jellyfin Ready/Shows/From (2022) [tvdbid-401003]/Season 01/From - S01E01.mkv` ... `S01E10.mkv`
- One manifest file documenting later drag-and-drop targets

### Definition of Done (verifiable conditions with commands)
- `test -d "/Volumes/x9-pro/Jellyfin Ready/Movies/28 Years Later - The Bone Temple (2026) [tmdbid-1272837]"`
- `test -d "/Volumes/x9-pro/Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/Season 01"`
- `test -d "/Volumes/x9-pro/Jellyfin Ready/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/Season 01"`
- `test -d "/Volumes/x9-pro/Jellyfin Ready/Shows/From (2022) [tvdbid-401003]/Season 01"`
- `test "$(ls -1 "/Volumes/x9-pro/Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/Season 01"/*.mkv | wc -l | tr -d ' ')" = "15"`
- `test "$(ls -1 "/Volumes/x9-pro/Jellyfin Ready/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/Season 01"/*.mkv | wc -l | tr -d ' ')" = "5"`
- `test "$(ls -1 "/Volumes/x9-pro/Jellyfin Ready/Shows/From (2022) [tvdbid-401003]/Season 01"/*.mkv | wc -l | tr -d ' ')" = "10"`
- `test ! -e "/Volumes/x9-pro/Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/nfo.screens.poster"`
- `test -f ".sisyphus/evidence/task-7-dragdrop-manifest.txt"`

### Must Have
- Stage only the four selected missing titles.
- Use the live Jellyfin naming convention already observed on `matt-desktop`.
- Move/rename media files in place on x9-pro; do not make a second full media copy.
- Keep the later drag-and-drop tree free of `.nfo`, torrent text files, and metadata junk folders.
- Record a manifest that tells the user exactly which staged folder later gets dropped into which Jellyfin library root.

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- Must NOT transfer anything to `/mnt/hdd` or `matt-desktop` in this phase.
- Must NOT modify already-transferred titles or unrelated x9-pro content.
- Must NOT include `Marty Supreme`, `Peaky Blinders`, `The Penguin`, or any non-selected title.
- Must NOT delete media or sidecar files; move them only.
- Must NOT leave `.nfo`, torrent text, or `nfo.screens.poster/` inside `Jellyfin Ready`.
- Must NOT rely on Jellyfin ingestion or DB checks in this phase.

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: `none`; verification is pure local filesystem checking.
- QA policy: Every task includes a happy-path and a failure/edge scenario.
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`
- Integrity method: compare file byte sizes before and after each move/rename.
- Readiness method: assert exact folder names, exact episode counts, and absence of junk from the ready tree.

## Execution Strategy
### Parallel Execution Waves
Wave 1: setup and safety
- 1. pre-flight source inventory and same-volume checks
- 2. create ready root and sidecar archive root

Wave 2: title staging
- 3. stage `28 Years Later - The Bone Temple`
- 4. stage `The Pitt`
- 5. stage `A Knight of the Seven Kingdoms`
- 6. stage `From`

Wave 3: manifest and final verification
- 7. generate drag-and-drop manifest
- 8. verify the final ready tree and source cleanup

### Dependency Matrix (full, all tasks)
| Task | Depends On | Blocks | Notes |
|---|---|---|---|
| 1 | none | 2,3,4,5,6 | Must pass before any move/rename |
| 2 | 1 | 3,4,5,6,7,8 | Creates the two canonical prep roots |
| 3 | 1,2 | 7,8 | Independent movie stage |
| 4 | 1,2 | 7,8 | Independent show stage |
| 5 | 1,2 | 7,8 | Split-source consolidation |
| 6 | 1,2 | 7,8 | Mixed-source consolidation |
| 7 | 3,4,5,6 | 8 | Writes the later drag/drop mapping |
| 8 | 3,4,5,6,7 | none | Final local readiness verification |

### Agent Dispatch Summary (wave -> task count -> categories)
- Wave 1 -> 2 tasks -> `quick`
- Wave 2 -> 4 tasks -> `deep`
- Wave 3 -> 2 tasks -> `quick`

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Pre-Flight Source Inventory And Same-Volume Checks

  **What to do**: Confirm that all selected source items exist, confirm `Jellyfin Ready` and `_jellyfin-prep-sidecars` will be created on the same `/Volumes/x9-pro` filesystem as the sources, compute the selected-source inventory, and record exact source byte sizes for every media file that will move.
  **Must NOT do**: Do not create directories yet. Do not move or rename anything. Do not inspect or touch unrelated titles.

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: pure local checks and inventory
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2,3,4,5,6 | Blocked By: none

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `/Volumes/x9-pro/Movies` - source movie root
  - Pattern: `/Volumes/x9-pro/Shows` - source show root
  - Pattern: `/mnt/hdd/Movies/Dunkirk (2017) [tmdbid-374720]/Dunkirk (2017).mkv` - movie naming pattern to mirror locally
  - Pattern: `/mnt/hdd/Shows/Deadwood (2004) [tvdbid-72023]/Season 01/Deadwood - S01E01.mkv` - show naming pattern to mirror locally
  - Source: `/Volumes/x9-pro/Movies/28.Years.Later.The.Bone.Temple.2026.2160p.iT.WEB-DL.DV.HDR10+.DDP5.1.Atmos.H265.MP4-BEN.THE.MEN/28.Years.Later.The.Bone.Temple.2026.2160p.iT.WEB-DL.DV.HDR10+[Ben The Men].mp4`
  - Source: `/Volumes/x9-pro/Shows/The.Pitt.S01.web-dl.sdr.2160p.av1.5.1.eac3.vmaf97-Dust`
  - Source: `/Volumes/x9-pro/Shows/From`
  - Source: `/Volumes/x9-pro/Shows/A.Knight.of.the.Seven.Kingdoms.S01E01.The.Hedge.Knight.2160p.HMAX.WEB-DL.DDP5.1.Atmos.DV.HDR.H.265-FLUX.mkv`
  - Source: `/Volumes/x9-pro/Shows/A Knight of the Seven Kingdoms S01E05 4K DV-HDR WebDL H265 AC3 5.1.mkv`
  - Source: `/Volumes/x9-pro/Shows/www.UIndex.org    -    A Knight of the Seven Kingdoms S01E02 Hard Salt Beef 2160p HMAX WEB-DL DDP5 1 DV H 265-NTb`
  - Source: `/Volumes/x9-pro/Shows/www.UIndex.org    -    A Knight of the Seven Kingdoms S01E03 The Squire 2160p HMAX WEB-DL DDP5 1 DV HDR H 265-NTb`
  - Source: `/Volumes/x9-pro/Shows/www.UIndex.org    -    A Knight of the Seven Kingdoms S01E04 Seven 2160p HMAX WEB-DL DDP5 1 Atmos DV HDR H 265-FLUX`

  **Acceptance Criteria** (agent-executable only):
  - [ ] all selected source paths exist before staging starts
  - [ ] inventory evidence records the exact media files and byte sizes that will move
  - [ ] the planned ready root and sidecar archive root both resolve to `/Volumes/x9-pro`
  - [ ] no file mutations have occurred yet

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path inventory succeeds
    Tool: Bash
    Steps: Enumerate all selected source media files; run `df -h /Volumes/x9-pro`; record exact source byte sizes with `stat`; write `.sisyphus/evidence/task-1-inventory.txt`
    Expected: Every selected source file/path is present and the evidence file contains a complete inventory
    Evidence: .sisyphus/evidence/task-1-inventory.txt

  Scenario: Failure if any required source path is missing
    Tool: Bash
    Steps: Check each required path explicitly before any later task starts
    Expected: Task exits non-zero and names the missing path; no staging directories are created
    Evidence: .sisyphus/evidence/task-1-inventory-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

- [x] 2. Create Ready Root And Sidecar Archive Root

  **What to do**: Create exactly these roots on x9-pro:
  - `READY_ROOT="/Volumes/x9-pro/Jellyfin Ready"`
  - `SIDECAR_ROOT="/Volumes/x9-pro/_jellyfin-prep-sidecars/$(date +%F)-prep"`
  Then create `Movies/` and `Shows/` under each root.
  **Must NOT do**: Do not move media yet. Do not create any other top-level prep root. Do not create hidden junk folders inside `Jellyfin Ready`.

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: low-risk local directory setup
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 3,4,5,6,7,8 | Blocked By: 1

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `/Volumes/x9-pro` - all prep work must stay on this filesystem
  - Pattern: `/Volumes/x9-pro/Jellyfin Ready` - user-facing drag/drop root
  - Pattern: `/Volumes/x9-pro/_jellyfin-prep-sidecars` - non-user-facing junk archive root

  **Acceptance Criteria** (agent-executable only):
  - [ ] `READY_ROOT/Movies` and `READY_ROOT/Shows` exist
  - [ ] `SIDECAR_ROOT/Movies` and `SIDECAR_ROOT/Shows` exist
  - [ ] no media files have moved yet

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path roots created
    Tool: Bash
    Steps: Create the exact ready root and sidecar root with `Movies` and `Shows` subdirectories; list them into an evidence file
    Expected: Both canonical roots exist and are empty except for their category subdirectories
    Evidence: .sisyphus/evidence/task-2-roots.txt

  Scenario: Failure if root path already exists as a non-directory
    Tool: Bash
    Steps: Check whether `Jellyfin Ready` or `_jellyfin-prep-sidecars` already exists as a non-directory before creating anything
    Expected: Task exits non-zero and does not continue to title staging
    Evidence: .sisyphus/evidence/task-2-roots-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

- [x] 3. Stage `28 Years Later - The Bone Temple`

  **What to do**: Move and rename the movie file to:
  - destination folder: `/Volumes/x9-pro/Jellyfin Ready/Movies/28 Years Later - The Bone Temple (2026) [tmdbid-1272837]`
  - destination file: `/Volumes/x9-pro/Jellyfin Ready/Movies/28 Years Later - The Bone Temple (2026) [tmdbid-1272837]/28 Years Later - The Bone Temple (2026).mp4`
  Remove the old ugly source folder by moving the file out of it; if the source folder becomes empty afterward, remove the empty folder.
  **Must NOT do**: Do not copy the movie. Do not leave the original filename in the ready tree. Do not create any sidecar archive entry because this source contains only the playable movie file.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: exact move+rename into canonical movie structure
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 7,8 | Blocked By: 1,2

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `/mnt/hdd/Movies/Furiosa - A Mad Max Saga (2024) [tmdbid-786892]/Furiosa - A Mad Max Saga (2024).mkv` - colon-to-hyphen movie subtitle pattern
  - External: `https://www.themoviedb.org/movie/1272837-28-years-later-the-bone-temple` - canonical movie title and tmdbid
  - Source folder: `/Volumes/x9-pro/Movies/28.Years.Later.The.Bone.Temple.2026.2160p.iT.WEB-DL.DV.HDR10+.DDP5.1.Atmos.H265.MP4-BEN.THE.MEN`
  - Source file: `/Volumes/x9-pro/Movies/28.Years.Later.The.Bone.Temple.2026.2160p.iT.WEB-DL.DV.HDR10+[Ben The Men].mp4`

  **Acceptance Criteria** (agent-executable only):
  - [ ] exact ready folder exists under `Jellyfin Ready/Movies`
  - [ ] exact ready movie file exists with canonical name
  - [ ] moved file byte size matches the original source byte size
  - [ ] old source folder is gone if it became empty

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path movie staging
    Tool: Bash
    Steps: Create the canonical ready folder; move+rename the MP4 into it; compare pre-move and post-move byte sizes; verify the old source folder is empty or gone
    Expected: The movie appears exactly once in the ready tree with the canonical filename
    Evidence: .sisyphus/evidence/task-3-28-years-later.txt

  Scenario: Failure if destination file already exists
    Tool: Bash
    Steps: Check the exact destination path before moving the movie
    Expected: Task exits non-zero and leaves the source movie untouched if the destination already exists
    Evidence: .sisyphus/evidence/task-3-28-years-later-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

- [x] 4. Stage `The Pitt`

  **What to do**: Move the 15 `.mkv` episode files from `/Volumes/x9-pro/Shows/The.Pitt.S01.web-dl.sdr.2160p.av1.5.1.eac3.vmaf97-Dust` into `/Volumes/x9-pro/Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/Season 01/`, renaming each file to `The Pitt - S01E##.mkv` by extracting the `S01E##` token. Move `nfo.screens.poster/` into `/Volumes/x9-pro/_jellyfin-prep-sidecars/$(date +%F)-prep/Shows/The Pitt (2025) [tvdbid-448176]/`. If the old source folder becomes empty after moves, remove it.
  **Must NOT do**: Do not copy the episodes. Do not keep `nfo.screens.poster/` inside the ready tree. Do not include episode titles in the ready filenames.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: batch move+rename plus metadata-folder separation
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 7,8 | Blocked By: 1,2

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `/mnt/hdd/Shows/Deadwood (2004) [tvdbid-72023]/Season 01/Deadwood - S01E01.mkv` - episode naming pattern to mirror locally
  - External: `https://thetvdb.com/series/the-pitt` - tvdbid 448176 and premiere year 2025
  - Source folder: `/Volumes/x9-pro/Shows/The.Pitt.S01.web-dl.sdr.2160p.av1.5.1.eac3.vmaf97-Dust`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `Jellyfin Ready/Shows/The Pitt (2025) [tvdbid-448176]/Season 01` contains exactly 15 `.mkv` files named `The Pitt - S01E01.mkv` through `The Pitt - S01E15.mkv`
  - [ ] `nfo.screens.poster/` no longer exists in the ready tree
  - [ ] the sidecar root contains `Shows/The Pitt (2025) [tvdbid-448176]/nfo.screens.poster/`
  - [ ] each moved episode byte size matches its pre-move byte size

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path show staging
    Tool: Bash
    Steps: Move+rename all 15 `.mkv` files into `Season 01`; move `nfo.screens.poster/` to the sidecar root; count destination `.mkv` files; compare per-file byte sizes
    Expected: Ready tree contains exactly 15 canonically named episodes and no metadata folder
    Evidence: .sisyphus/evidence/task-4-the-pitt.txt

  Scenario: Failure if a non-`.mkv` item would remain in the ready tree
    Tool: Bash
    Steps: Enumerate the staged show root after the move and fail if `nfo.screens.poster/`, `.nfo`, or `.txt` remains there
    Expected: Task fails instead of leaving non-media clutter in the drag/drop tree
    Evidence: .sisyphus/evidence/task-4-the-pitt-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

- [x] 5. Stage `A Knight of the Seven Kingdoms`

  **What to do**: Consolidate the split show sources into `/Volumes/x9-pro/Jellyfin Ready/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/Season 01/` using this exact mapping:
  - `A Knight of the Seven Kingdoms - S01E01.mkv` <- `/Volumes/x9-pro/Shows/A.Knight.of.the.Seven.Kingdoms.S01E01.The.Hedge.Knight.2160p.HMAX.WEB-DL.DDP5.1.Atmos.DV.HDR.H.265-FLUX.mkv`
  - `A Knight of the Seven Kingdoms - S01E02.mkv` <- `/Volumes/x9-pro/Shows/www.UIndex.org    -    A Knight of the Seven Kingdoms S01E02 Hard Salt Beef 2160p HMAX WEB-DL DDP5 1 DV H 265-NTb/A Knight of the Seven Kingdoms S01E02 Hard Salt Beef 2160p HMAX WEB-DL DDP5 1 DV H 265-NTb.mkv`
  - `A Knight of the Seven Kingdoms - S01E03.mkv` <- `/Volumes/x9-pro/Shows/www.UIndex.org    -    A Knight of the Seven Kingdoms S01E03 The Squire 2160p HMAX WEB-DL DDP5 1 DV HDR H 265-NTb/A Knight of the Seven Kingdoms S01E03 The Squire 2160p HMAX WEB-DL DDP5 1 DV HDR H 265-NTb.mkv`
  - `A Knight of the Seven Kingdoms - S01E04.mkv` <- `/Volumes/x9-pro/Shows/www.UIndex.org    -    A Knight of the Seven Kingdoms S01E04 Seven 2160p HMAX WEB-DL DDP5 1 Atmos DV HDR H 265-FLUX/A Knight of the Seven Kingdoms S01E04 Seven 2160p HMAX WEB-DL DDP5 1 Atmos DV HDR H 265-FLUX.mkv`
  - `A Knight of the Seven Kingdoms - S01E05.mkv` <- `/Volumes/x9-pro/Shows/A Knight of the Seven Kingdoms S01E05 4K DV-HDR WebDL H265 AC3 5.1.mkv`
  Move the three `.mkv.nfo` files and the three torrent text files from the UIndex folders into `/Volumes/x9-pro/_jellyfin-prep-sidecars/$(date +%F)-prep/Shows/A Knight of the Seven Kingdoms (2026) [tvdbid-433631]/`. Remove the emptied UIndex folders after they are fully drained.
  **Must NOT do**: Do not leave the split source structure in place. Do not rename the show to `...The Hedge Knight`. Do not leave `.nfo` or torrent text inside the ready tree.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: split-source consolidation with explicit sidecar separation
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 7,8 | Blocked By: 1,2

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `/mnt/hdd/Shows/Deadwood (2004) [tvdbid-72023]/Season 01/Deadwood - S01E01.mkv` - canonical episode naming to mirror locally
  - External: `https://thetvdb.com/series/a-knight-of-the-seven-kingdoms-the-hedge-knight` - display title, tvdbid 433631, premiere year 2026
  - Source files and folders: all five exact source media paths plus the three UIndex folders listed in **What to do**

  **Acceptance Criteria** (agent-executable only):
  - [ ] `Season 01` contains exactly 5 `.mkv` files named `A Knight of the Seven Kingdoms - S01E01.mkv` through `...S01E05.mkv`
  - [ ] the ready tree contains no `.nfo` or torrent text files for this title
  - [ ] the sidecar root contains the three `.mkv.nfo` files and three torrent text files under the canonical show folder
  - [ ] the old loose episode files and the old UIndex folders are gone from `/Volumes/x9-pro/Shows`

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path split-source consolidation
    Tool: Bash
    Steps: Move+rename the five exact media files into one canonical `Season 01`; move the six sidecar files into the sidecar root; verify ready-tree count is 5 and sidecar count is 6
    Expected: One clean canonical season folder replaces the old split source layout
    Evidence: .sisyphus/evidence/task-5-a-knight.txt

  Scenario: Failure if any UIndex sidecar remains mixed with media
    Tool: Bash
    Steps: Enumerate both the ready tree and the original UIndex paths after the move
    Expected: Task fails if any `.nfo` or torrent text remains in the ready tree or in a half-drained UIndex folder
    Evidence: .sisyphus/evidence/task-5-a-knight-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

- [x] 6. Stage `From`

  **What to do**: Consolidate `From` season 1 into `/Volumes/x9-pro/Jellyfin Ready/Shows/From (2022) [tvdbid-401003]/Season 01/` using this exact numbering policy:
  - `From - S01E01.mkv` through `From - S01E07.mkv` come from the seven UIndex episode folders in `/Volumes/x9-pro/Shows/From/`
  - `From - S01E08.mkv` comes from `/Volumes/x9-pro/Shows/From/From.S01E08.Finestre.rotte.porte.aperte.2160p.WEBMux.ITA.ENG.x265-BlackBit.mkv`
  - `From - S01E09.mkv` and `From - S01E10.mkv` come from the remaining two UIndex episode folders
  Move all UIndex `.mkv.nfo` files and torrent text files into `/Volumes/x9-pro/_jellyfin-prep-sidecars/$(date +%F)-prep/Shows/From (2022) [tvdbid-401003]/`. Remove emptied UIndex folders, and remove the old `/Volumes/x9-pro/Shows/From` source folder if it becomes empty after staging.
  **Must NOT do**: Do not preserve the Italian episode title in the ready filename. Do not leave `.nfo` or torrent text in the ready tree.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: mixed-source consolidation with strict episode-token handling
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 7,8 | Blocked By: 1,2

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `/mnt/hdd/Shows/Deadwood (2004) [tvdbid-72023]/Season 01/Deadwood - S01E01.mkv` - canonical episode naming to mirror locally
  - External: `https://thetvdb.com/series/from` - canonical title, tvdbid 401003, premiere year 2022
  - Source folder: `/Volumes/x9-pro/Shows/From`
  - Source example: `/Volumes/x9-pro/Shows/From/From.S01E08.Finestre.rotte.porte.aperte.2160p.WEBMux.ITA.ENG.x265-BlackBit.mkv`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `Season 01` contains exactly 10 `.mkv` files named `From - S01E01.mkv` through `From - S01E10.mkv`
  - [ ] the ready tree contains no `.nfo` or torrent text files for this title
  - [ ] the sidecar root contains all `.mkv.nfo` and torrent text files moved out of the old UIndex folders
  - [ ] the old `/Volumes/x9-pro/Shows/From` source folder is gone if emptied by staging

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path mixed-source consolidation
    Tool: Bash
    Steps: Move+rename the ten exact media files into one canonical `Season 01`; move the UIndex sidecars into the sidecar root; verify ready-tree count is 10
    Expected: One clean canonical season folder replaces the old mixed source layout
    Evidence: .sisyphus/evidence/task-6-from.txt

  Scenario: Failure if episode numbering is incomplete or duplicated
    Tool: Bash
    Steps: Validate the source mapping resolves to the exact set `S01E01`..`S01E10` before and after the move
    Expected: Task fails instead of producing a ready tree with missing or duplicate episode numbers
    Evidence: .sisyphus/evidence/task-6-from-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

- [x] 7. Generate Drag-And-Drop Manifest

  **What to do**: Write `.sisyphus/evidence/task-7-dragdrop-manifest.txt` that maps each prepared ready-tree folder to its later drop target:
  - `Jellyfin Ready/Movies/<title-folder>` -> later drag into `/mnt/hdd/Movies/`
  - `Jellyfin Ready/Shows/<title-folder>` -> later drag into `/mnt/hdd/Shows/`
  Include the exact staged paths for all four titles and the exact sidecar archive paths for later rollback/reference.
  **Must NOT do**: Do not write vague instructions like "drop this somewhere in Movies". Do not include non-selected titles.

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: evidence and handoff generation
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: 8 | Blocked By: 3,4,5,6

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `/Volumes/x9-pro/Jellyfin Ready/Movies`
  - Pattern: `/Volumes/x9-pro/Jellyfin Ready/Shows`
  - Pattern: `/mnt/hdd/Movies`
  - Pattern: `/mnt/hdd/Shows`
  - Sidecar root from task 2

  **Acceptance Criteria** (agent-executable only):
  - [ ] manifest file exists at `.sisyphus/evidence/task-7-dragdrop-manifest.txt`
  - [ ] manifest contains exactly four ready-tree title folders and exactly two later drop roots (`/mnt/hdd/Movies`, `/mnt/hdd/Shows`)
  - [ ] manifest includes sidecar archive locations for `The Pitt`, `A Knight`, and `From`

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path manifest generation
    Tool: Bash
    Steps: Enumerate the final ready-tree title folders; write a one-line mapping for each to its later Jellyfin drop root; include sidecar archive references
    Expected: Manifest gives exact later drag-and-drop instructions for the prepared titles
    Evidence: .sisyphus/evidence/task-7-dragdrop-manifest.txt

  Scenario: Failure if manifest omits a selected title
    Tool: Bash
    Steps: Compare the expected title set against the generated manifest entries
    Expected: Task fails if the manifest does not contain all four selected titles exactly once
    Evidence: .sisyphus/evidence/task-7-dragdrop-manifest-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

- [x] 8. Verify Final Ready Tree And Source Cleanup

  **What to do**: Run a final local verification pass that proves the ready tree is clean and complete, the old messy selected-source locations are gone, and the sidecar archive holds the moved junk. Record all results in `.sisyphus/evidence/task-8-final-verify.txt`.
  **Must NOT do**: Do not transfer anything to `matt-desktop`. Do not leave the final verification at a fuzzy title-only level; use exact paths and exact counts.

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: final local readiness verification only
  - Skills: `[]` - no special skills required
  - Omitted: `git-master` - no git operations

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: none | Blocked By: 3,4,5,6,7

  **References** (executor has NO interview context - be exhaustive):
  - Ready root from task 2
  - Sidecar root from task 2
  - Exact staged paths from tasks 3-6
  - Manifest path from task 7

  **Acceptance Criteria** (agent-executable only):
  - [ ] ready tree contains exactly 1 prepared movie folder and exactly 3 prepared show folders for the selected scope
  - [ ] ready tree contains only playable media files plus canonical season folders; no `.nfo`, `.txt`, `nfo.screens.poster/`, or `www.UIndex.org` names remain inside it
  - [ ] old messy selected-source paths are absent from their original locations
  - [ ] sidecar archive contains the moved non-media leftovers for `The Pitt`, `A Knight`, and `From`
  - [ ] manifest file exists and matches the final ready tree

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```text
  Scenario: Happy path final verification
    Tool: Bash
    Steps: Enumerate the ready tree and sidecar root; assert exact title folders and exact episode counts; assert no junk remains in the ready tree; compare results against the manifest
    Expected: The staged tree is drag-and-drop-ready and the old selected-source clutter is gone
    Evidence: .sisyphus/evidence/task-8-final-verify.txt

  Scenario: Failure if any selected source still remains in the old messy location
    Tool: Bash
    Steps: Explicitly test the old selected-source paths after staging
    Expected: Task fails if any old selected source path still exists in a way that would confuse the later drag/drop workflow
    Evidence: .sisyphus/evidence/task-8-final-verify-error.txt
  ```

  **Commit**: NO | Message: `n/a` | Files: none

## Final Verification Wave (4 parallel agents, ALL must APPROVE)
- [ ] F1. Plan Compliance Audit - oracle
- [ ] F2. Code Quality Review - unspecified-high
- [ ] F3. Real Manual QA - unspecified-high (+ playwright if UI)
- [ ] F4. Scope Fidelity Check - deep

## Commit Strategy
- No git commit is part of this plan.
- This work prepares media on `/Volumes/x9-pro`; it does not change repo-tracked code.
- The only repo-local artifacts expected from execution are evidence files under `.sisyphus/evidence/`.

## Success Criteria
- Exactly four selected titles are staged under `/Volumes/x9-pro/Jellyfin Ready`.
- Their folder and file names already match the live Jellyfin pattern used on `matt-desktop`.
- The later drag-and-drop action is unambiguous: movie title folder -> `/mnt/hdd/Movies`, show title folders -> `/mnt/hdd/Shows`.
- The ready tree contains no `.nfo`, torrent text, `nfo.screens.poster/`, or `www.UIndex.org` junk.
- The old messy selected-source locations are cleaned up because the selected media has been moved into the ready tree.
- Non-media leftovers are preserved in `/Volumes/x9-pro/_jellyfin-prep-sidecars/$(date +%F)-prep/` instead of being deleted.
