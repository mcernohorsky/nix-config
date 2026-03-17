# Learnings: opencode-shared-setup

## 2026-03-17 Session Start

### Architecture Decisions
- Shared OpenCode core module will be platform-agnostic (no Portal, launchd, systemd, Tailscale)
- Desktop web service uses `opencode web --hostname 127.0.0.1 --port 4097` (not Portal, not `opencode serve`)
- Tailscale Serve exposes the localhost-only web UI to tailnet
- `OPENCODE_SERVER_PASSWORD` via agenix for defense-in-depth HTTP auth
- Working directory on matt-desktop: `/home/matt/Developer` (created if missing)

### Key Constraints
- Portal stays macbook-only, untouched
- No ACL redesign in this work
- No reverse proxy (nginx/caddy)
- No giant cross-platform "agent stack" module

### File References
- `hosts/macbook-pro-m2/home/home.nix:57` - OpenCode core config JSON
- `hosts/macbook-pro-m2/home/home.nix:78` - oh-my-opencode.json generation
- `hosts/macbook-pro-m2/home/home.nix:519` - programs.opencode wiring
- `hosts/macbook-pro-m2/home/opencode-plugins.json` - plugin pins (to be moved)
- `hosts/macbook-pro-2/modules/portal.nix` - Portal module (preserve as-is)
- `flake.nix:149` - matt-desktop Home Manager wiring target
- `justfile:17` - update-plugins automation (needs path update)

### Parallelization
- Wave 1: T1 and T2 can run in parallel (no dependencies between them)
- T3 and T4 depend on T1 and T2 completing
- T5 depends on T4

## 2026-03-16 T1 Completion

### Shared Module Extraction
- Created `modules/home/opencode-core.nix` as a platform-agnostic Home Manager module with `options.modules.home.opencodeCore.*`
- Extracted `.config/opencode/config.json` generation (model + provider) into module-managed `home.file` entries
- Extracted `.config/opencode/oh-my-opencode.json` generation into configurable `ohMyOpenCode` option default
- Extracted `programs.opencode` wiring, including package resolution via `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode`
- Kept plugin pin loading pattern in module scope: `opencode-plugins = builtins.fromJSON (builtins.readFile ./opencode-plugins.json);`

### Guardrails Validated
- No Portal/launchd/systemd/Tailscale Serve references in `modules/home/opencode-core.nix`
- No hardcoded `/Users/matt` paths in the shared module
## T2: Move plugin pin source (2026-03-16)

### Completed
- Moved `hosts/macbook-pro-m2/home/opencode-plugins.json` → `modules/home/opencode-plugins.json`
- Updated `justfile` lines 27-28 to write to new path
- JSON content preserved: oh-my-opencode 3.11.2, opencode-quotas 0.0.3

### Verification Results
- `jq .` parses successfully at new location
- Old file removed from macbook-pro-m2 path
- Only new canonical path referenced in justfile and modules
- Reference in `hosts/macbook-pro-m2/home/home.nix:9` remains (to be updated by T1)

### Pattern
File moves in Nix repos require:
1. Physical file move with `mv`
2. Update automation that writes to the path
3. Verification with `rg` to ensure no orphaned references
4. Clear documentation that remaining old references will be handled by dependent tasks

## 2026-03-16 T5 Completion

### Desktop App Packaging
- `inputs.llm-agents.packages.x86_64-linux` exposes `opencode` but not `opencode-desktop`
- `nixpkgs.legacyPackages.x86_64-linux.opencode-desktop` exists and is cross-platform metadata-wise, with `meta.mainProgram = "OpenCode"`
- `hosts/matt-desktop/home.nix` can install the desktop client declaratively by adding `pkgs.opencode-desktop` to `home.packages`

### Verification Gotcha
- `nix eval .#...` can fail while host modules are still untracked because Git flakes omit untracked files; `path:/Users/matt/.config/nix-config#...` includes the working tree for local verification

## 2026-03-16 T6 Completion

### Host-specific OpenCode Web Service
- Added `hosts/matt-desktop/modules/opencode-web.nix` with `systemd.services.opencode-web`
- Service uses `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode`
- Exec command pinned to localhost-only binding: `opencode web --hostname 127.0.0.1 --port 4097`
- Service runs as user `matt` with restart policy `on-failure`
- Imported module in `hosts/matt-desktop/configuration.nix` via `./modules/opencode-web.nix`
