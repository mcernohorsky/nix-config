# Audiobookshelf on matt-desktop

## TL;DR
> **Summary**: Add Audiobookshelf to the existing `matt-desktop` NixOS media module, expose it only on the Tailscale interface, and point its audiobook library at `/mnt/hdd/audiobooks` while keeping app state on the SSD.
> **Deliverables**:
> - Audiobookshelf service config in `hosts/matt-desktop/modules/media.nix`
> - Tailscale-only firewall rule in `hosts/matt-desktop/configuration.nix`
> - Library directory bootstrap and permission wiring for `/mnt/hdd/audiobooks`
> - Deploy + smoke-test evidence for service health and remote reachability
> **Effort**: Short
> **Parallel**: NO
> **Critical Path**: Task 1 -> Task 2 -> Task 3 -> Task 4 -> Task 5 -> Task 6

## Context
### Original Request
Come up with a plan to install an audiobook server on `matt-desktop`.

### Interview Summary
- Server choice is `Audiobookshelf`.
- Exposure stays Tailscale-only, with no public reverse proxy and no LAN-wide firewall opening.
- The audiobook library lives under `/mnt/hdd`; use `/mnt/hdd/audiobooks` as the exact directory.
- Verification strategy is tests-after: validate Nix config first, then deploy, then run smoke tests.

### Metis Review (gaps addressed)
- Resolved the default port conflict with Restic (`8000`) by pinning Audiobookshelf to `13378`.
- Resolved NTFS mount access by keeping the service user as `audiobookshelf` and granting `users` group read access.
- Resolved ambiguous exposure by choosing direct Tailscale port access (`http://matt-desktop.tailc41cf5.ts.net:13378`) instead of adding Tailscale Serve or a reverse proxy.
- Resolved ambiguous metadata placement by keeping Audiobookshelf state on the SSD-backed default `/var/lib/audiobookshelf` path.

## Work Objectives
### Core Objective
Install Audiobookshelf on `matt-desktop` via existing NixOS host configuration so the service starts automatically, can read `/mnt/hdd/audiobooks`, and is reachable only over Tailscale on port `13378`.

### Deliverables
- `hosts/matt-desktop/modules/media.nix` updated to configure Audiobookshelf.
- `hosts/matt-desktop/configuration.nix` updated to allow TCP `13378` on `tailscale0` only.
- `/mnt/hdd/audiobooks` bootstrapped declaratively and readable by the Audiobookshelf service.
- Deployment verification artifacts captured under `.sisyphus/evidence/`.

### Definition of Done (verifiable conditions with commands)
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` exits `0`.
- `ssh matt@matt-desktop.tailc41cf5.ts.net "systemctl is-active audiobookshelf"` returns `active`.
- `ssh matt@matt-desktop.tailc41cf5.ts.net "ss -tln | grep 13378"` shows Audiobookshelf listening.
- `curl --fail --connect-timeout 5 http://matt-desktop.tailc41cf5.ts.net:13378/` returns HTTP `200`.
- `ssh matt@matt-desktop.tailc41cf5.ts.net "test -d /mnt/hdd/audiobooks"` exits `0`.

### Must Have
- Use the existing host module structure rooted at `hosts/matt-desktop/configuration.nix:4`.
- Keep Audiobookshelf config in `hosts/matt-desktop/modules/media.nix:1` beside the existing Jellyfin config.
- Use port `13378`.
- Use direct Tailscale access only.
- Keep `services.audiobookshelf.openFirewall = false` and manage exposure with the `tailscale0` firewall rule.
- Keep Audiobookshelf metadata/config on the SSD via the module default `dataDir` under `/var/lib/audiobookshelf`.

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- Must NOT add Caddy, Nginx, Tailscale Serve, or any public-domain exposure.
- Must NOT change `flake.nix`, `hardware-configuration.nix`, or unrelated host modules.
- Must NOT reuse port `8000` or open `13378` on all interfaces.
- Must NOT move Jellyfin or refactor unrelated media services.
- Must NOT require manual file creation outside the declared Nix config.
- Must NOT treat app onboarding (creating the first admin user or adding the library in the UI) as part of this plan.

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: tests-after using Nix evaluation, remote service checks, and HTTP smoke tests
- QA policy: Every task includes agent-executed scenarios with command-level checks
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.txt`

## Execution Strategy
### Parallel Execution Waves
> Small-scope exception: all config-edit tasks are serialized because they touch the same host files and depend on one another.

Wave 1: Tasks 1-5 (host config changes in `media.nix` and `configuration.nix`)
Wave 2: Task 6 (deploy and end-to-end verification)

### Dependency Matrix (full, all tasks)
| Task | Depends On | Blocks |
|------|------------|--------|
| 1 | none | 2, 3, 4, 5, 6 |
| 2 | 1 | 3, 4, 5, 6 |
| 3 | 2 | 4, 5, 6 |
| 4 | 3 | 5, 6 |
| 5 | 4 | 6 |
| 6 | 5 | Final Verification Wave |

### Agent Dispatch Summary (wave -> task count -> categories)
- Wave 1 -> 5 tasks -> `quick`
- Wave 2 -> 1 task -> `unspecified-low`

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Add the Audiobookshelf service block to the media module

  **What to do**: Update `hosts/matt-desktop/modules/media.nix` to add `services.audiobookshelf` alongside `services.jellyfin` with `enable = true`, `host = "0.0.0.0"`, `port = 13378`, and `openFirewall = false`. Do not set a custom `dataDir`; keep the module default so metadata stays under `/var/lib/audiobookshelf` on the SSD.
  **Must NOT do**: Do not remove or refactor Jellyfin. Do not set `openFirewall = true`. Do not bind Audiobookshelf to `127.0.0.1` because the chosen exposure model is direct tailnet access, not Tailscale Serve.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: single-file Nix service addition following an existing local pattern
  - Skills: `[]` — Native Nix edits are sufficient
  - Omitted: `[]` — No extra skills are needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2, 3, 4, 5, 6 | Blocked By: none

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `hosts/matt-desktop/modules/media.nix:5` — Existing media-service placement and style to extend rather than replace
  - Pattern: `hosts/matt-desktop/configuration.nix:153` — Example of service exposure being managed outside the service block via firewall rules
  - API/Type: `https://aux-docs.pyrox.pages.gay/NixOS/services/audiobookshelf/` — NixOS option names and defaults for `enable`, `host`, `port`, `openFirewall`, and `dataDir`
  - External: `https://www.audiobookshelf.org/docs` — Product defaults and recommended port context (`13378`)

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "services.audiobookshelf" hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `grep -n 'port = 13378;' hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `grep -n 'host = "0.0.0.0";' hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `grep -n 'openFirewall = false;' hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Service options are declared exactly as planned
    Tool: Bash
    Steps: Run `grep -n "services.audiobookshelf" hosts/matt-desktop/modules/media.nix`; run `grep -n 'port = 13378;' hosts/matt-desktop/modules/media.nix`; run `grep -n 'host = "0.0.0.0";' hosts/matt-desktop/modules/media.nix`
    Expected: All three commands return at least one match and point to the new Audiobookshelf block
    Evidence: .sisyphus/evidence/task-1-service-block.txt

  Scenario: Config still evaluates after service insertion
    Tool: Bash
    Steps: Run `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build`
    Expected: Exit code `0` with no evaluation error
    Evidence: .sisyphus/evidence/task-1-service-block-error.txt
  ```

  **Commit**: NO | Message: `feat(matt-desktop): add audiobookshelf service block` | Files: `hosts/matt-desktop/modules/media.nix`

- [x] 2. Bootstrap `/mnt/hdd/audiobooks` and grant the service read access to the NTFS mount

  **What to do**: In `hosts/matt-desktop/modules/media.nix`, add `systemd.tmpfiles.rules` for `d /mnt/hdd/audiobooks 0755 matt users -` and add `users.users.audiobookshelf.extraGroups = [ "users" ];`. Keep the service user as `audiobookshelf`; the goal is read access to the NTFS mount through group membership, not running the app as `matt`.
  **Must NOT do**: Do not modify `hosts/matt-desktop/hardware-configuration.nix`. Do not remount `/mnt/hdd`. Do not change the Audiobookshelf user to `matt`.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: small Nix changes with a fixed ownership model
  - Skills: `[]` — Native Nix edits are sufficient
  - Omitted: `[]` — No extra skills are needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 3, 4, 5, 6 | Blocked By: 1

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `hosts/matt-desktop/modules/media.nix:19` — Existing service-specific user customization (`users.users.jellyfin.extraGroups`)
  - Pattern: `hosts/matt-desktop/configuration.nix:203` — Existing `systemd.tmpfiles.rules` style in this host
  - API/Type: `hosts/matt-desktop/hardware-configuration.nix:17` — `/mnt/hdd` mount details show NTFS with `uid=1000` and `gid=100` (`users`)
  - External: `https://www.audiobookshelf.org/docs` — Audiobooks are mounted as a separate content directory from config/metadata

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n 'users.users.audiobookshelf.extraGroups = \[ "users" \ ];' hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `grep -n '/mnt/hdd/audiobooks 0755 matt users -' hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Permission model matches the NTFS mount strategy
    Tool: Bash
    Steps: Run `grep -n 'users.users.audiobookshelf.extraGroups = \[ "users" \ ];' hosts/matt-desktop/modules/media.nix`; run `grep -n '/mnt/hdd/audiobooks 0755 matt users -' hosts/matt-desktop/modules/media.nix`
    Expected: Both commands return matches; the service keeps its own user and gains `users` group membership
    Evidence: .sisyphus/evidence/task-2-library-perms.txt

  Scenario: No forbidden mount changes were introduced
    Tool: Bash
    Steps: Run `grep -n '/mnt/hdd' hosts/matt-desktop/hardware-configuration.nix`; run `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build`
    Expected: The hardware mount definition remains unchanged and evaluation succeeds
    Evidence: .sisyphus/evidence/task-2-library-perms-error.txt
  ```

  **Commit**: NO | Message: `feat(matt-desktop): grant audiobookshelf access to audiobook library` | Files: `hosts/matt-desktop/modules/media.nix`

- [x] 3. Make Audiobookshelf wait for the HDD mount before starting

  **What to do**: Add a systemd override in `hosts/matt-desktop/modules/media.nix` so the generated `audiobookshelf.service` includes `RequiresMountsFor = [ "/mnt/hdd" "/mnt/hdd/audiobooks" ];`. This task exists to prevent startup races after boot when the NTFS disk is still mounting.
  **Must NOT do**: Do not add custom mount units. Do not edit `hardware-configuration.nix`. Do not add broad `After=network.target` style overrides unrelated to the disk dependency.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: targeted systemd override in the same module
  - Skills: `[]` — Native Nix edits are sufficient
  - Omitted: `[]` — No extra skills are needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 4, 5, 6 | Blocked By: 2

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `hosts/matt-desktop/hardware-configuration.nix:17` — Confirms `/mnt/hdd` is an actual mount, not a plain directory
  - Pattern: `hosts/matt-desktop/modules/media.nix:1` — Systemd overrides for the media stack belong in this module
  - API/Type: `https://aux-docs.pyrox.pages.gay/NixOS/services/audiobookshelf/` — Confirms this is a standard NixOS service suitable for `systemd.services.audiobookshelf` overrides

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n 'RequiresMountsFor = \[ "/mnt/hdd" "/mnt/hdd/audiobooks" \ ];' hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Service explicitly depends on the HDD mount
    Tool: Bash
    Steps: Run `grep -n 'RequiresMountsFor = \[ "/mnt/hdd" "/mnt/hdd/audiobooks" \ ];' hosts/matt-desktop/modules/media.nix`
    Expected: The command returns exactly one match in the Audiobookshelf systemd override block
    Evidence: .sisyphus/evidence/task-3-mount-order.txt

  Scenario: Override does not break Nix evaluation
    Tool: Bash
    Steps: Run `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build`
    Expected: Exit code `0` with no missing-attribute or type errors
    Evidence: .sisyphus/evidence/task-3-mount-order-error.txt
  ```

  **Commit**: NO | Message: `feat(matt-desktop): wait for audiobook storage mount` | Files: `hosts/matt-desktop/modules/media.nix`

- [x] 4. Open Audiobookshelf only on the Tailscale interface

  **What to do**: Update `hosts/matt-desktop/configuration.nix` so `networking.firewall.interfaces."tailscale0".allowedTCPPorts` includes `13378` alongside the existing Restic port `8000`. Keep this as an interface-scoped rule; do not use a global firewall allowance and do not rely on `services.audiobookshelf.openFirewall`.
  **Must NOT do**: Do not open `13378` in the default/global firewall. Do not change Tailscale service settings. Do not remove the existing Restic port allowance.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: one small, deterministic firewall edit in a single host file
  - Skills: `[]` — Native Nix edits are sufficient
  - Omitted: `[]` — No extra skills are needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 5, 6 | Blocked By: 3

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `hosts/matt-desktop/configuration.nix:153` — Existing `tailscale0` interface-scoped firewall rule for Restic
  - Pattern: `hosts/matt-desktop/configuration.nix:124` — Tailscale is already enabled and is the intended private access path
  - Pattern: `hosts/matt-desktop/configuration.nix:97` — OpenSSH is intentionally not opened globally, reinforcing the host's private-exposure posture
  - API/Type: `https://aux-docs.pyrox.pages.gay/NixOS/services/audiobookshelf/` — `openFirewall` is optional and should stay `false` here

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n 'allowedTCPPorts = \[ 8000 13378 \ ];' hosts/matt-desktop/configuration.nix` returns a match
  - [ ] `grep -n 'openFirewall = false;' hosts/matt-desktop/modules/media.nix` returns a match
  - [ ] `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Firewall rule is limited to tailscale0
    Tool: Bash
    Steps: Run `grep -n 'networking.firewall.interfaces."tailscale0".allowedTCPPorts = \[ 8000 13378 \ ];' hosts/matt-desktop/configuration.nix`
    Expected: The command returns one match showing `13378` only in the `tailscale0` rule
    Evidence: .sisyphus/evidence/task-4-tailscale-firewall.txt

  Scenario: No broad service firewall opening was introduced
    Tool: Bash
    Steps: Run `grep -n 'openFirewall = false;' hosts/matt-desktop/modules/media.nix`; run `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build`
    Expected: The service keeps `openFirewall = false` and the config still evaluates successfully
    Evidence: .sisyphus/evidence/task-4-tailscale-firewall-error.txt
  ```

  **Commit**: NO | Message: `feat(matt-desktop): expose audiobookshelf on tailscale only` | Files: `hosts/matt-desktop/configuration.nix`, `hosts/matt-desktop/modules/media.nix`

- [x] 5. Run pre-deploy validation for the full `matt-desktop` configuration

  **What to do**: After all config edits are complete, run `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` from the repo root. If evaluation fails, fix the Nix errors before any deploy attempt. Optionally run `ssh matt@matt-desktop.tailc41cf5.ts.net "sudo nixos-rebuild test --flake ~/.config/nix-config#matt-desktop"` only if remote pre-activation testing is needed after a clean evaluation.
  **Must NOT do**: Do not deploy while evaluation is red. Do not treat `deploy-rs --skip-checks` as a substitute for the explicit eval step.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: command-only validation against an already-decided config
  - Skills: `[]` — Native shell and Nix commands are sufficient
  - Omitted: `[]` — No extra skills are needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 6 | Blocked By: 4

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `flake.nix:141` — Confirms the exact flake target name `nixosConfigurations.matt-desktop`
  - Pattern: `.sisyphus/plans/matt-desktop-review.md:86` — Prior host work used `nix eval ... --no-build` as the standard validation gate
  - Pattern: `justfile:63` — Deploy command exists, but this validation step must happen before it
  - Pattern: `hosts/matt-desktop/home.nix:1208` — Local `nixos-rebuild switch` alias exists if remote rebuild testing is needed later

  **Acceptance Criteria** (agent-executable only):
  - [ ] `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Final config evaluates cleanly before deploy
    Tool: Bash
    Steps: Run `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build`
    Expected: Exit code `0` and no evaluation error output
    Evidence: .sisyphus/evidence/task-5-predeploy-eval.txt

  Scenario: Validation gate catches errors before deploy
    Tool: Bash
    Steps: If the command fails, capture stderr and stop the workflow; do not run `just deploy-desktop` until the error is fixed
    Expected: No deploy command runs while evaluation is failing
    Evidence: .sisyphus/evidence/task-5-predeploy-eval-error.txt
  ```

  **Commit**: NO | Message: `chore(matt-desktop): validate audiobookshelf config before deploy` | Files: `hosts/matt-desktop/configuration.nix`, `hosts/matt-desktop/modules/media.nix`

- [x] 6. Deploy to `matt-desktop` and capture runtime smoke-test evidence

  **What to do**: Deploy with `just deploy-desktop`. After deploy, verify the service is active, confirm the process is listening on `13378`, confirm the library directory exists, and confirm the web UI responds over the tailnet at `http://matt-desktop.tailc41cf5.ts.net:13378/`. Treat deploy-rs output as incomplete until the remote checks pass, since this repo already documents unreliable confirmation during activation.
  **Must NOT do**: Do not add a public health endpoint. Do not change the verification target to a public hostname. Do not consider the task complete based only on `deploy-rs` output.

  **Recommended Agent Profile**:
  - Category: `unspecified-low` — Reason: deployment plus several runtime checks across local and remote commands
  - Skills: `[]` — Native shell and SSH commands are sufficient
  - Omitted: `[]` — No extra skills are needed

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: Final Verification Wave | Blocked By: 5

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `justfile:63` — Standard remote deployment command for this host
  - Pattern: `flake.nix:185` — `matt-desktop` deploy-rs node and remote-build context
  - Pattern: `flake.nix:169` — Repo note that deploy confirmation can be unreliable during activation; runtime verification is mandatory
  - Pattern: `hosts/matt-desktop/configuration.nix:153` — Firewall exposure model to preserve
  - External: `https://www.audiobookshelf.org/docs` — Root web UI should respond on the configured port after startup

  **Acceptance Criteria** (agent-executable only):
  - [ ] `ssh matt@matt-desktop.tailc41cf5.ts.net "systemctl is-active audiobookshelf"` returns `active`
  - [ ] `ssh matt@matt-desktop.tailc41cf5.ts.net "ss -tln | grep 13378"` returns a listening socket
  - [ ] `ssh matt@matt-desktop.tailc41cf5.ts.net "test -d /mnt/hdd/audiobooks && stat -c '%U:%G %a' /mnt/hdd/audiobooks"` exits `0`
  - [ ] `curl --fail --connect-timeout 5 http://matt-desktop.tailc41cf5.ts.net:13378/` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Happy path deploy and tailnet access
    Tool: Bash
    Steps: Run `just deploy-desktop`; regardless of deploy-rs chatter, run `ssh matt@matt-desktop.tailc41cf5.ts.net "systemctl is-active audiobookshelf"`; run `ssh matt@matt-desktop.tailc41cf5.ts.net "ss -tln | grep 13378"`; run `curl --fail --connect-timeout 5 http://matt-desktop.tailc41cf5.ts.net:13378/`
    Expected: The service is `active`, port `13378` is listening, and the HTTP request succeeds
    Evidence: .sisyphus/evidence/task-6-deploy-verify.txt

  Scenario: Storage path and runtime state are both valid after deploy
    Tool: Bash
    Steps: Run `ssh matt@matt-desktop.tailc41cf5.ts.net "test -d /mnt/hdd/audiobooks && stat -c '%U:%G %a' /mnt/hdd/audiobooks"`; if the service check fails, run `ssh matt@matt-desktop.tailc41cf5.ts.net "systemctl status audiobookshelf --no-pager"`
    Expected: The library directory exists, ownership reports `matt:users 755`, and any failure captures actionable service status output
    Evidence: .sisyphus/evidence/task-6-deploy-verify-error.txt
  ```

  **Commit**: YES | Message: `feat(matt-desktop): add audiobookshelf server` | Files: `hosts/matt-desktop/configuration.nix`, `hosts/matt-desktop/modules/media.nix`

## Final Verification Wave (4 parallel agents, ALL must APPROVE)
- [x] F1. Plan Compliance Audit — oracle
- [x] F2. Code Quality Review — unspecified-high
- [x] F3. Real Manual QA — unspecified-high (+ playwright if UI)
- [x] F4. Scope Fidelity Check — deep

## Commit Strategy
- Make one commit after Task 6 succeeds: `feat(matt-desktop): add audiobookshelf server`
- Do not commit intermediate broken states.

## Success Criteria
- `matt-desktop` boots and activates with Audiobookshelf enabled.
- Audiobookshelf is reachable at `http://matt-desktop.tailc41cf5.ts.net:13378/` from the tailnet.
- `/mnt/hdd/audiobooks` exists and is readable by the service.
- No public or LAN-wide exposure is introduced.
