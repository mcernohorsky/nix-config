# Shared OpenCode Setup and Desktop Web Access

## TL;DR

> **Quick Summary**: Extract the cross-platform OpenCode CLI/TUI config out of the macbook-only Home Manager file, reuse it on `matt-desktop`, then add a host-specific always-on `opencode web` service on `matt-desktop` that is exposed privately through Tailscale Serve for iPhone access.
>
> **Deliverables**:
> - Shared Home Manager OpenCode core module used by both `macbook-pro-m2` and `matt-desktop`
> - `matt-desktop` OpenCode TUI plus desktop app installation
> - `matt-desktop` localhost-only `opencode web` service with Tailscale Serve exposure
> - Updated plugin-pin automation and operator commands/docs
> - Deferred follow-up TODO to evaluate alternative mobile UIs after the initial path lands
>
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: T1 -> T3/T4 -> T6 -> T7/T8 -> T12

---

## Context

### Original Request
Factor the current OpenCode setup out of this macbook's Nix configuration so it can also be used on `matt-desktop`, then ultimately reach an always-on desktop-hosted UI over Tailscale from an iPhone. Keep the first version simple by using the default OpenCode web UI, add a follow-up TODO to evaluate alternatives later, and make sure `matt-desktop` gets both the OpenCode TUI and desktop app.

### Interview Summary

**Key Discussions**:
- Initial UI target is the default OpenCode web UI, not Portal.
- Alternative/mobile-specific UIs are explicitly deferred until after the first shared setup works.
- Verification strategy is `tests-after`, using Nix/build/service/network checks rather than introducing a new automated test harness first.
- `opencode-desktop` is already present for macOS; this plan adds equivalent desktop-app coverage for `matt-desktop` only.
- Shared OpenCode model policy needs one canonical source: `small_model` stays `opencode-go/minimax-m2.5`, while the Kimi agent lanes use direct Fireworks IDs and only fall back to `opencode-go/kimi-k2.5` where explicitly intended.

**Research Findings**:
- Current shared-reuse blockers live in `hosts/macbook-pro-m2/home/home.nix`, `hosts/macbook-pro-m2/home/opencode-plugins.json`, and `hosts/macbook-pro-m2/modules/portal.nix`.
- `flake.nix` wires macOS and Linux Home Manager separately, so there is no current shared OpenCode module.
- `matt-desktop` already has Tailscale with `--ssh` and a trusted tag, but no OpenCode config or service.
- Current Portal/Tailscale exposure on macOS is imperative and Darwin-specific, so it should not be the basis of the shared extraction.
- Homebrew casks on macOS live in `hosts/macbook-pro-m2/configuration.nix`; Linux app install work must follow existing `matt-desktop` package patterns instead.
- Mid-refactor drift proved the risk of dual sources of truth: the macbook host kept an inline `oh-my-opencode.json` block with stale MiniMax/Nemotron/Gemini fallback chains even after `modules/home/opencode-core.nix` existed, so the shared module must become the active source for both hosts before any model-policy changes are trustworthy.
- Direct Fireworks Kimi naming is not the same as OpenRouter naming: the shared config should target `fireworks/accounts/fireworks/models/kimi-k2p5`, not `openrouter/moonshotai/kimi-k2.5`.
- Fireworks direct-provider wiring also has a provider-shape pitfall: OpenCode expects Fireworks as an OpenAI-compatible provider with provider-level `options.baseURL`, so a model-level `baseURL` override can produce runtime `undefined/chat/completions` failures even when `nix eval` looks correct.

### Metis Review

**Identified Gaps** (addressed):
- `opencode web` vs `opencode serve`: resolved to `opencode web` because the user wants the default web UI first.
- Working directory on `matt-desktop`: defaulted to `/home/matt/Developer`, with directory creation included if absent.
- Auth bootstrap: resolved to a documented one-time `opencode auth login` bootstrap step on `matt-desktop`, outside acceptance criteria.
- HTTP auth ambiguity: defaulted to using `OPENCODE_SERVER_PASSWORD` through agenix for defense in depth.
- Plugin pin automation path drift: explicitly included as a task so `just update-plugins` keeps working after extraction.

---

## Work Objectives

### Core Objective
Create a reusable OpenCode core configuration that works across both hosts without dragging along macOS-only Portal/service logic, then add a secure, always-on `matt-desktop` web entrypoint that is reachable from the tailnet and practical from an iPhone.

### Concrete Deliverables
- Shared Home Manager module for OpenCode CLI/TUI config and generated JSON config files
- Shared plugin-pin JSON location plus updated `just update-plugins`
- `macbook-pro-m2` continuing to work with existing Portal config untouched
- `matt-desktop` receiving OpenCode CLI/TUI and desktop app installation
- `matt-desktop` NixOS module for `opencode web --hostname 127.0.0.1 --port 4097`
- `matt-desktop` Tailscale Serve exposure for the localhost-only web UI
- Documented post-deploy auth bootstrap and deferred alternative-UI evaluation checklist

### Definition of Done
- [x] `macbook-pro-m2` and `matt-desktop` both evaluate/build with the new shared module wiring
- [ ] `matt-desktop` has declarative OpenCode CLI/TUI plus a declarative desktop-app install path
- [ ] `matt-desktop` OpenCode web service binds only to localhost and is reachable through Tailscale Serve
- [ ] `just update-plugins` writes to the new shared plugin-pin location
- [ ] Deferred TODOs for Portal/OpenChamber/other UI evaluation are captured, but not implemented now
- [x] Shared OpenCode model policy is identical on both hosts: `small_model = opencode-go/minimax-m2.5`, Kimi agent lanes use direct Fireworks IDs, and no stale MiniMax/Nemotron/Grok chains remain in active agent/category paths

### Must Have
- Preserve current macbook behavior while extracting shared OpenCode core config
- Keep shared module platform-agnostic
- Use `opencode web`, not Portal, as the initial desktop-hosted phone-access path
- Install both OpenCode TUI and desktop app on `matt-desktop`
- Require agent-executable verification only
- Eliminate host-local OpenCode config drift so both hosts consume the same shared agent and fallback policy

### Must NOT Have (Guardrails)
- No Portal refactor or Linux Portal port in this work
- No Tailscale ACL redesign in this work; only consume the current tailnet model safely
- No reverse proxy layer such as nginx/caddy for the desktop OpenCode UI
- No giant cross-platform "agent stack" module that mixes shared config with host service/exposure logic
- No refactor of unrelated `matt-desktop` desktop configuration beyond the OpenCode-related additions
- No silent fallback-policy divergence between `hosts/macbook-pro-m2/home/home.nix` and `modules/home/opencode-core.nix`

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** for acceptance. Manual auth bootstrap may be documented, but acceptance and QA must be agent-executed.

### Test Decision
- **Infrastructure exists**: Limited
- **Automated tests**: Tests-after
- **Framework**: Nix build/eval + service checks + curl/Tailscale checks
- **If TDD**: Not selected

### QA Policy
Every implementation task includes runnable checks. Evidence goes under `.sisyphus/evidence/`.

- **Config/module work**: `nix build`, `nix eval`, file-path/content checks
- **Desktop service work**: `systemctl`/`journalctl` checks plus localhost `curl`
- **Tailscale exposure work**: `tailscale serve status` plus HTTPS `curl` from a tailnet-reachable context
- **Desktop app work**: executable/desktop-entry existence checks and launchability smoke checks if headless-safe

---

## Execution Strategy

### Parallel Execution Waves

Wave 1 (Start Immediately - shared extraction foundations):
- T1: Create shared OpenCode core module
- T2: Move plugin pin source and update automation
- T3: Rewire macbook to consume shared module without touching Portal
- T4: Rewire matt-desktop Home Manager to consume shared module and install TUI
- T5: Add `matt-desktop` desktop-app installation path

Wave 2 (After Wave 1 - desktop service and secure exposure):
- T6: Add `matt-desktop` OpenCode web service module
- T7: Add service env, working-directory prep, and password-secret wiring
- T8: Add `matt-desktop` Tailscale Serve publication/reconciliation
- T9: Add operator commands for desktop OpenCode service status/logs/reset

Wave 3 (After Wave 2 - docs and integration verification):
- T10: Document auth bootstrap, deployment flow, and phone-access path
- T11: Verify cross-host config-output/build regression
- T12: Run desktop remote-access smoke checks and capture evidence

Wave FINAL (After ALL tasks - independent review):
- F1: Plan compliance audit
- F2: Code quality/build review
- F3: Real QA replay of every scenario
- F4: Scope fidelity check

Critical Path: T1 -> T3/T4 -> macbook deploy checkpoint -> T6 -> T7 -> T8 -> T12
Parallel Speedup: ~55% faster than sequential
Max Concurrent: 5

### Dependency Matrix

- **T1**: blocked by none -> blocks T3, T4, T11
- **T2**: blocked by none -> blocks T3, T4, T9, T11
- **T3**: blocked by T1, T2 -> blocks T11
- **T4**: blocked by T1, T2 -> blocks T5, T6, T7, T11
- **T5**: blocked by T4 -> blocks T11
- **T6**: blocked by T4 -> blocks T7, T8, T12
- **T7**: blocked by T4, T6 -> blocks T8, T10, T12
- **T8**: blocked by T6, T7 -> blocks T9, T10, T12
- **T9**: blocked by T2, T8 -> blocks T12
- **T10**: blocked by T7, T8 -> blocks T12
- **T11**: blocked by T1, T2, T3, T4, T5 -> blocks T12
- **T12**: blocked by T6, T7, T8, T9, T10, T11 -> blocks F1-F4

### Agent Dispatch Summary

- **Wave 1**: T1 `deep`, T2 `quick`, T3 `quick`, T4 `quick`, T5 `unspecified-high`
- **Wave 2**: T6 `deep`, T7 `unspecified-high`, T8 `unspecified-high`, T9 `quick`
- **Wave 3**: T10 `writing`, T11 `unspecified-high`, T12 `deep`
- **FINAL**: F1 `oracle`, F2 `unspecified-high`, F3 `unspecified-high`, F4 `deep`

---

## TODOs

- [x] 1. Create shared OpenCode core Home Manager module

  **What to do**:
  - Add a new top-level shared module (for example `modules/home/opencode-core.nix`) containing only the reusable OpenCode CLI/TUI configuration currently embedded in `hosts/macbook-pro-m2/home/home.nix`.
  - Move the generated `.config/opencode/config.json` and `.config/opencode/oh-my-opencode.json` logic into that shared module.
  - Keep the module free of Portal, launchd, systemd, Tailscale, and hardcoded host paths.

  **Must NOT do**:
  - Do not move the existing `services.portal` block or `../modules/portal.nix` import into the shared module.
  - Do not add Darwin/Linux branching beyond what is strictly needed for package path resolution.

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Cross-platform extraction with config-preservation constraints.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: no UI design work here.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T2)
  - **Blocks**: T3, T4, T11
  - **Blocked By**: None

  **References**:
  - `hosts/macbook-pro-m2/home/home.nix:57` - Existing generated OpenCode core config JSON.
  - `hosts/macbook-pro-m2/home/home.nix:78` - Existing `oh-my-opencode.json` generation and shared agent/category settings.
  - `hosts/macbook-pro-m2/home/home.nix:519` - Existing `programs.opencode` wiring to preserve.
  - `flake.nix:149` - Linux Home Manager wiring target that will eventually consume the shared module.

  **Acceptance Criteria**:
  - [ ] Shared module file exists and contains only reusable OpenCode core concerns.
  - [ ] No Portal/service/Tailscale settings appear inside the shared module.
  - [ ] `nix build .#darwinConfigurations.macbook-pro-m2.system` succeeds after the shared module is wired in later tasks.

  **QA Scenarios**:
  ```text
  Scenario: Shared module structure is clean
    Tool: Bash
    Preconditions: Module file added to repo
    Steps:
      1. Run `grep -n "portal\|launchd\|systemd\|tailscale serve" modules/home/opencode-core.nix`
      2. Expect no matches for service/exposure concerns
    Expected Result: The shared module contains only core OpenCode config
    Failure Indicators: Any Portal/service/Tailscale lines are present
    Evidence: .sisyphus/evidence/task-1-clean-module.txt

  Scenario: Core config payload still evaluates
    Tool: Bash
    Preconditions: Shared module imported on at least one host
    Steps:
      1. Run `nix build .#darwinConfigurations.macbook-pro-m2.system`
      2. Capture exit code and any eval/build output
    Expected Result: Build exits 0
    Failure Indicators: Evaluation error, missing option, infinite recursion, or attr-path failure
    Evidence: .sisyphus/evidence/task-1-darwin-build.txt
  ```

  **Evidence to Capture**:
  - [ ] Module cleanliness search output
  - [ ] Darwin build output after integration

  **Commit**: YES
  - Message: `refactor(opencode): extract shared core module`
  - Files: `modules/home/opencode-core.nix`
  - Pre-commit: `nix build .#darwinConfigurations.macbook-pro-m2.system`

- [x] 2. Move plugin pin source and update plugin automation

  **What to do**:
  - Relocate `hosts/macbook-pro-m2/home/opencode-plugins.json` to the new shared OpenCode module area.
  - Update the shared module and `just update-plugins` so plugin pins remain declarative and no longer write into a macbook-only path.
  - Preserve current plugin versions and JSON shape.

  **Must NOT do**:
  - Do not change plugin versions as part of this refactor.
  - Do not leave `just update-plugins` writing to a stale host-specific location.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small focused path migration and automation update.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `writing`: behavior change is operational, not prose-heavy.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1)
  - **Blocks**: T3, T4, T9, T11
  - **Blocked By**: None

  **References**:
  - `hosts/macbook-pro-m2/home/opencode-plugins.json` - Current canonical plugin-pin file.
  - `hosts/macbook-pro-m2/home/home.nix:9` - Current reader of the plugin-pin JSON.
  - `justfile:17` - `update-plugins` automation that must be repointed.

  **Acceptance Criteria**:
  - [ ] Shared plugin-pin JSON exists in the new location.
  - [ ] `just update-plugins` writes to the new location.
  - [ ] Both host configs read the shared plugin-pin file successfully.

  **QA Scenarios**:
  ```text
  Scenario: Automation points at new shared path
    Tool: Bash
    Preconditions: justfile updated
    Steps:
      1. Run `rg -n "opencode-plugins.json" justfile modules hosts`
      2. Confirm the write target is the shared path and no stale write target remains under `hosts/macbook-pro-m2/home/`
    Expected Result: Only the new canonical path is used for writes
    Failure Indicators: justfile still writes to the old macbook path
    Evidence: .sisyphus/evidence/task-2-plugin-paths.txt

  Scenario: Shared pin file parses successfully
    Tool: Bash
    Preconditions: Shared JSON file moved
    Steps:
      1. Run `jq . modules/home/opencode-plugins.json`
      2. Verify jq exits 0 and prints the existing keys
    Expected Result: Valid JSON with preserved keys
    Failure Indicators: Invalid JSON or missing plugin keys
    Evidence: .sisyphus/evidence/task-2-plugin-json.txt
  ```

  **Evidence to Capture**:
  - [ ] Ripgrep output for path references
  - [ ] Parsed JSON output

  **Commit**: YES
  - Message: `chore(opencode): centralize plugin pin source`
  - Files: `modules/home/opencode-plugins.json`, `justfile`
  - Pre-commit: `jq . modules/home/opencode-plugins.json`

- [x] 3. Rewire macbook to use the shared OpenCode core while preserving Portal

  **What to do**:
  - Replace the duplicated macbook OpenCode core config with an import/use of the new shared module.
  - Keep `../modules/portal.nix` and the existing `services.portal` enablement untouched.
  - Ensure the generated OpenCode JSON and CLI behavior remain identical on macOS.

  **Must NOT do**:
  - Do not rewrite or modernize `portal.nix`.
  - Do not change macbook OpenCode behavior except path indirection to shared config.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small import/wiring change with strong regression constraints.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `deep`: task should stay narrow once T1/T2 land.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: T11
  - **Blocked By**: T1, T2

  **References**:
  - `hosts/macbook-pro-m2/home/home.nix:12` - Existing imports block.
  - `hosts/macbook-pro-m2/home/home.nix:19` - Existing Portal service enablement to preserve.
  - `hosts/macbook-pro-m2/modules/portal.nix:79` - Portal module options; keep compatibility stable.

  **Acceptance Criteria**:
  - [x] `hosts/macbook-pro-m2/home/home.nix` consumes the shared module.
  - [x] `services.portal` remains enabled with the existing settings.
  - [x] `nix build .#darwinConfigurations.macbook-pro-m2.system` exits 0.

  **QA Scenarios**:
  ```text
  Scenario: macbook build regression passes
    Tool: Bash
    Preconditions: macbook Home Manager wiring updated
    Steps:
      1. Run `nix build .#darwinConfigurations.macbook-pro-m2.system`
      2. Capture exit code and build output
    Expected Result: Build exits 0
    Failure Indicators: Home Manager import error, missing file path, or changed option names
    Evidence: .sisyphus/evidence/task-3-darwin-build.txt

  Scenario: Portal wiring remains present
    Tool: Bash
    Preconditions: home.nix edited
    Steps:
      1. Run `rg -n "services\.portal|portal\.nix" hosts/macbook-pro-m2/home/home.nix`
      2. Verify the import and enable block still exist
    Expected Result: Portal import and service enablement remain in place
    Failure Indicators: Missing import or service block
    Evidence: .sisyphus/evidence/task-3-portal-wiring.txt
  ```

  **Evidence to Capture**:
  - [x] Darwin build output
  - [x] Portal wiring grep output

  **Commit**: YES
  - Message: `refactor(macbook): consume shared opencode core`
  - Files: `hosts/macbook-pro-m2/home/home.nix`
  - Pre-commit: `nix build .#darwinConfigurations.macbook-pro-m2.system`

- [x] 4. Rewire matt-desktop Home Manager to use the shared OpenCode core and install the TUI

  **What to do**:
  - Import/use the shared OpenCode core from `hosts/matt-desktop/home.nix`.
  - Ensure `matt-desktop` gets the OpenCode CLI/TUI package and generated config files.
  - Preserve the rest of the large desktop Home Manager file without unrelated cleanup.

  **Must NOT do**:
  - Do not modularize unrelated sections of `hosts/matt-desktop/home.nix`.
  - Do not add Portal to `matt-desktop` in this phase.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Focused host import/wiring change.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `writing`: not doc-centric.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: T5, T6, T7, T11
  - **Blocked By**: T1, T2

  **References**:
  - `flake.nix:164` - `matt-desktop` Home Manager user wiring.
  - `hosts/matt-desktop/home.nix` - Large host file to keep mostly untouched.
  - `hosts/macbook-pro-m2/home/home.nix:519` - Current OpenCode program wiring to reuse.

  **Acceptance Criteria**:
  - [x] `hosts/matt-desktop/home.nix` consumes the shared OpenCode core.
  - [x] `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel` exits 0.
  - [x] The resulting desktop config includes OpenCode CLI/TUI installation and generated config files.

  **QA Scenarios**:
  ```text
  Scenario: Linux host builds with shared core
    Tool: Bash
    Preconditions: matt-desktop Home Manager updated
    Steps:
      1. Run `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`
      2. Capture exit code and build output
    Expected Result: Build exits 0
    Failure Indicators: Missing package for x86_64-linux, bad import, or option mismatch
    Evidence: .sisyphus/evidence/task-4-linux-build.txt

  Scenario: TUI package is present in eval output
    Tool: Bash
    Preconditions: matt-desktop buildable
    Steps:
      1. Run `nix eval .#nixosConfigurations.matt-desktop.config.home-manager.users.matt.programs.opencode.enable`
      2. Verify the value is `true`
    Expected Result: OpenCode program is enabled for matt-desktop user
    Failure Indicators: Value is false or attr path is missing
    Evidence: .sisyphus/evidence/task-4-opencode-enabled.txt
  ```

  **Evidence to Capture**:
  - [x] Linux build output
  - [x] Nix eval output for OpenCode enablement

  **Commit**: YES
  - Message: `feat(desktop): add shared opencode core`
  - Files: `hosts/matt-desktop/home.nix`
  - Pre-commit: `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`

- [x] 5. Add declarative desktop-app installation for matt-desktop

  **What to do**:
  - Add the OpenCode desktop app to `matt-desktop` using the host's existing declarative package/application pattern.
  - Prefer a native Nix/Home Manager package path first; if unavailable, add the smallest repo-consistent declarative wrapper needed.
  - Keep this task limited to the desktop app and avoid dragging the web service into it.

  **Must NOT do**:
  - Do not change the macbook cask list for this task.
  - Do not introduce ad-hoc manual install instructions as the primary implementation.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: May require package-source discovery or wrapper work.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `quick`: package availability may require deeper investigation.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: T11
  - **Blocked By**: T4

  **References**:
  - `hosts/macbook-pro-m2/configuration.nix:67` - Existing macOS app-install intent for `opencode-desktop`.
  - `hosts/matt-desktop/home.nix` - Linux user package wiring target.
  - `https://opencode.ai/docs/` - Official OpenCode docs root for desktop-app/package discovery if a Linux package source must be confirmed.

  **Acceptance Criteria**:
  - [ ] `matt-desktop` declaratively installs the OpenCode desktop app or a documented repo-local wrapper if native package support is missing.
  - [ ] `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel` still exits 0.
  - [ ] The resulting system exposes a launchable desktop-app entry or binary path.

  **QA Scenarios**:
  ```text
  Scenario: Desktop app package resolves in build
    Tool: Bash
    Preconditions: desktop-app install path added
    Steps:
      1. Run `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`
      2. Capture output and ensure package resolution succeeds
    Expected Result: Build exits 0 with desktop app included
    Failure Indicators: Package not found, unsupported platform, or wrapper build failure
    Evidence: .sisyphus/evidence/task-5-desktop-app-build.txt

  Scenario: Desktop app path or desktop file exists
    Tool: Bash
    Preconditions: system closure built
    Steps:
      1. Inspect the built closure with `rg -n "opencode-desktop|OpenCode" result/ -g '*.desktop'`
      2. Confirm a desktop entry or binary path exists
    Expected Result: A concrete launch target exists for the desktop app
    Failure Indicators: No desktop entry and no application binary path
    Evidence: .sisyphus/evidence/task-5-desktop-app-entry.txt
  ```

  **Evidence to Capture**:
  - [ ] Desktop-app build output
  - [ ] Desktop entry or binary discovery output

  **Commit**: YES
  - Message: `feat(desktop): add opencode desktop app`
  - Files: `hosts/matt-desktop/home.nix` or small supporting packaging file(s)
  - Pre-commit: `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`

- [x] 6. Add a host-specific matt-desktop OpenCode web service module

  **What to do**:
  - Create `hosts/matt-desktop/modules/opencode-web.nix` for an always-on `opencode web --hostname 127.0.0.1 --port 4097` service.
  - Wire the module into `hosts/matt-desktop/configuration.nix` following existing host-specific module patterns.
  - Make the service run under the desktop user context or a clearly defined service identity consistent with the plan's security defaults.

  **Must NOT do**:
  - Do not use `opencode serve`; this task targets the default web UI.
  - Do not bind to `0.0.0.0` or expose the service directly on the LAN.

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: New NixOS service module with process/lifecycle/security constraints.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `quick`: service-module correctness matters more than speed.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: T7, T8, T12
  - **Blocked By**: T4

  **References**:
  - `hosts/matt-desktop/modules/media.nix` - Existing host-specific service module style.
  - `hosts/matt-desktop/configuration.nix:144` - Existing Tailscale host context.
  - `https://opencode.ai/docs/web/` - Canonical `opencode web` mode and flags.

  **Acceptance Criteria**:
  - [ ] `hosts/matt-desktop/modules/opencode-web.nix` exists and is imported by the desktop host.
  - [ ] Service command uses `opencode web --hostname 127.0.0.1 --port 4097`.
  - [ ] `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel` exits 0.

  **QA Scenarios**:
  ```text
  Scenario: Service module evaluates and builds
    Tool: Bash
    Preconditions: opencode-web module added and imported
    Steps:
      1. Run `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`
      2. Capture output and verify success
    Expected Result: Desktop system closure builds successfully
    Failure Indicators: Missing module import, bad systemd unit structure, or bad attr reference
    Evidence: .sisyphus/evidence/task-6-service-build.txt

  Scenario: Service binds only to localhost
    Tool: Bash
    Preconditions: desktop host deployed or test VM available
    Steps:
      1. Run `systemctl status opencode-web`
      2. Run `ss -ltnp | rg ':4097'`
      3. Verify the listener is `127.0.0.1:4097` only
    Expected Result: Service is active and bound to localhost only
    Failure Indicators: Service inactive or bound to `0.0.0.0`/tailscale interface directly
    Evidence: .sisyphus/evidence/task-6-localhost-bind.txt
  ```

  **Evidence to Capture**:
  - [ ] Service build output
  - [ ] `systemctl` and socket-listener output

  **Commit**: YES
  - Message: `feat(desktop): add opencode web service`
  - Files: `hosts/matt-desktop/modules/opencode-web.nix`, `hosts/matt-desktop/configuration.nix`
  - Pre-commit: `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`

- [x] 7. Add service environment, password secret, and working-directory preparation

  **What to do**:
  - Add `OPENCODE_SERVER_PASSWORD` via agenix and wire it into the desktop web service for HTTP basic auth.
  - Set the working directory to `/home/matt/Developer` and ensure the directory exists declaratively if absent.
  - Document the one-time `opencode auth login` bootstrap as an operator step rather than an acceptance gate.

  **Must NOT do**:
  - Do not bake provider auth tokens into the repo.
  - Do not make manual auth bootstrap part of the pass/fail QA criteria.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Secret wiring plus service environment and filesystem prep.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `writing`: docs are secondary to the secret/env plumbing.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: T8, T10, T12
  - **Blocked By**: T4, T6

  **References**:
  - `secrets/secrets.nix:18` - Existing agenix secret registration pattern.
  - `hosts/matt-desktop/configuration.nix:139` - Existing secret consumption style.
  - `hosts/macbook-pro-m2/home/home.nix:518` - Current note about OpenCode auth token location.
  - `https://opencode.ai/docs/server/` - Server-password behavior.

  **Acceptance Criteria**:
  - [ ] A new agenix secret exists for `OPENCODE_SERVER_PASSWORD` and is wired only to the desktop service.
  - [ ] `/home/matt/Developer` exists or is declaratively created by the deployed config.
  - [ ] Desktop system build remains green.

  **QA Scenarios**:
  ```text
  Scenario: Password-protected service rejects anonymous access
    Tool: Bash (curl)
    Preconditions: desktop service deployed and running
    Steps:
      1. Run `curl -i http://127.0.0.1:4097`
      2. Verify response status is `401` or the documented auth challenge response
    Expected Result: Anonymous request is not granted UI access
    Failure Indicators: Returns `200` without credentials or service crashes
    Evidence: .sisyphus/evidence/task-7-anon-rejected.txt

  Scenario: Working directory exists before service start
    Tool: Bash
    Preconditions: deployment applied
    Steps:
      1. Run `test -d /home/matt/Developer && pwd`
      2. Run `systemctl status opencode-web`
      3. Verify the unit is active and not failing on missing directory
    Expected Result: Directory exists and service starts cleanly
    Failure Indicators: Missing directory or unit failure referencing WorkingDirectory
    Evidence: .sisyphus/evidence/task-7-working-dir.txt
  ```

  **Evidence to Capture**:
  - [ ] Anonymous curl auth challenge output
  - [ ] Working-directory and service-status output

  **Commit**: YES
  - Message: `feat(desktop): secure opencode web service`
  - Files: `secrets/secrets.nix`, desktop service module, secret file reference(s)
  - Pre-commit: `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`

- [x] 8. Add matt-desktop Tailscale Serve publication/reconciliation

  **What to do**:
  - Add declarative or reconciled host-specific Tailscale Serve setup for the desktop OpenCode web service.
  - Keep the backend on localhost and publish only through Tailscale Serve.
  - Ensure service exposure survives rebuilds/restarts and remains inspectable with `tailscale serve status`.

  **Must NOT do**:
  - Do not use Tailscale Funnel.
  - Do not open the OpenCode web port directly in the firewall.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Exposure state must remain safe and reproducible.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `deep`: the service already exists; this task is focused on exposure orchestration.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: T9, T10, T12
  - **Blocked By**: T6, T7

  **References**:
  - `hosts/macbook-pro-m2/configuration.nix:165` - Existing imperative Serve pattern to mirror conceptually, not literally.
  - `tailscale-acl.json:13` - Current tailnet access model that will gate the served UI.
  - `https://tailscale.com/docs/features/tailscale-serve` - Official Serve behavior and localhost guidance.

  **Acceptance Criteria**:
  - [ ] Desktop host has a reproducible Tailscale Serve configuration for the OpenCode web UI.
  - [ ] `tailscale serve status` shows the desktop UI published from `127.0.0.1:4097`.
  - [ ] No new firewall rule is added for the OpenCode web port.

  **QA Scenarios**:
  ```text
  Scenario: Tailscale Serve publishes the localhost web UI
    Tool: Bash
    Preconditions: desktop service and Serve config deployed
    Steps:
      1. Run `tailscale serve status`
      2. Verify the status output maps `/` to `http://127.0.0.1:4097`
    Expected Result: Serve is configured and visible in status output
    Failure Indicators: No Serve entry, wrong backend port, or direct non-localhost target
    Evidence: .sisyphus/evidence/task-8-serve-status.txt

  Scenario: HTTPS path works through the tailnet URL
    Tool: Bash (curl)
    Preconditions: tailnet HTTPS enabled and Serve active
    Steps:
      1. Run `curl -k -I https://matt-desktop.tailc41cf5.ts.net`
      2. Verify response status is `200`, `302`, or `401` depending on auth flow, but not connection failure
    Expected Result: Tailscale HTTPS endpoint is reachable
    Failure Indicators: DNS failure, TLS failure, connection refused, or 5xx from backend
    Evidence: .sisyphus/evidence/task-8-tailnet-https.txt
  ```

  **Evidence to Capture**:
  - [ ] `tailscale serve status` output
  - [ ] HTTPS HEAD response output

  **Commit**: YES
  - Message: `feat(desktop): publish opencode web over tailscale`
  - Files: `hosts/matt-desktop/configuration.nix` or small supporting module/unit files
  - Pre-commit: `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`

- [x] 9. Add operator commands for desktop OpenCode service management

  **What to do**:
  - Extend `justfile` with commands for desktop OpenCode service status, logs, restart, and Serve status/reset.
  - Keep naming and host-variable usage consistent with existing `portal-*`, `ssh-desktop`, and Tailscale helpers.
  - Ensure commands target `matt-desktop` over SSH when appropriate.

  **Must NOT do**:
  - Do not remove existing Portal commands.
  - Do not mix Oracle operations into the new desktop OpenCode commands.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small operational CLI additions matching an existing file pattern.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `writing`: command additions matter more than prose.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: T12
  - **Blocked By**: T2, T8

  **References**:
  - `justfile:92` - Existing SSH host-target command style.
  - `justfile:108` - Existing Tailscale-status helper pattern.
  - `justfile:132` - Existing Portal operational commands for naming consistency.

  **Acceptance Criteria**:
  - [ ] `justfile` contains desktop OpenCode commands for status/logs/restart/Serve status or reset.
  - [ ] Commands reference `matt-desktop` consistently and do not clobber existing Portal helpers.

  **QA Scenarios**:
  ```text
  Scenario: just command list shows new desktop OpenCode helpers
    Tool: Bash
    Preconditions: justfile updated
    Steps:
      1. Run `just --list`
      2. Verify the new desktop OpenCode recipes appear with expected names
    Expected Result: Operators can discover the new commands from the justfile
    Failure Indicators: Missing commands or naming collisions
    Evidence: .sisyphus/evidence/task-9-just-list.txt

  Scenario: Desktop status command resolves correctly
    Tool: Bash
    Preconditions: desktop command added
    Steps:
      1. Run the status helper in dry/real form appropriate to the justfile style
      2. Verify it reaches `matt-desktop` and returns service or Serve status
    Expected Result: Command succeeds and reports status
    Failure Indicators: SSH target mismatch, unknown recipe, or broken command body
    Evidence: .sisyphus/evidence/task-9-status-command.txt
  ```

  **Evidence to Capture**:
  - [ ] `just --list` output
  - [ ] Status helper output

  **Commit**: YES
  - Message: `chore(ops): add desktop opencode helpers`
  - Files: `justfile`
  - Pre-commit: `just --list`

- [x] 10. Document auth bootstrap, deployment flow, and deferred UI evaluation

  **What to do**:
  - Update repo docs with the one-time `matt-desktop` OpenCode auth bootstrap flow, deployment steps, and phone-access URL/path.
  - Explicitly record that alternative UI evaluation is deferred until after the first shared/default-web path succeeds.
  - Capture the follow-up checklist for Portal/OpenChamber/other UI evaluation as deferred TODOs, not current deliverables.

  **Must NOT do**:
  - Do not silently turn deferred UI evaluation into current implementation work.
  - Do not document public-internet exposure or Funnel usage.

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Main output is operator-facing documentation and deferred TODO capture.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `quick`: documentation quality matters more than raw speed.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: T12
  - **Blocked By**: T7, T8

  **References**:
  - `README.md` - Repo-wide setup and structure documentation.
  - `DEPLOYMENT.md` - Existing Tailscale/deploy operational documentation.
  - `https://opencode.ai/docs/web/` - Default web-mode terminology to mirror.

  **Acceptance Criteria**:
  - [ ] Docs describe desktop auth bootstrap, service access path, and the deferred alternative-UI evaluation note.
  - [ ] Docs keep the current plan scoped to default OpenCode web UI first.

  **QA Scenarios**:
  ```text
  Scenario: Deferred UI note is documented
    Tool: Bash
    Preconditions: docs updated
    Steps:
      1. Run `rg -n "OpenChamber|Portal|alternative UI|deferred" README.md DEPLOYMENT.md`
      2. Confirm the alternative-UI work is labeled as follow-up, not current scope
    Expected Result: Docs preserve the agreed scope boundary
    Failure Indicators: Docs imply Portal or another UI is part of current implementation
    Evidence: .sisyphus/evidence/task-10-deferred-ui.txt

  Scenario: Auth bootstrap steps are present
    Tool: Bash
    Preconditions: docs updated
    Steps:
      1. Run `rg -n "opencode auth login|OPENCODE_SERVER_PASSWORD|matt-desktop" README.md DEPLOYMENT.md`
      2. Confirm desktop bootstrap and access steps are documented
    Expected Result: Operators have concrete setup instructions
    Failure Indicators: Missing auth/bootstrap or access instructions
    Evidence: .sisyphus/evidence/task-10-bootstrap-docs.txt
  ```

  **Evidence to Capture**:
  - [ ] Deferred UI note grep output
  - [ ] Auth bootstrap doc grep output

  **Commit**: YES
  - Message: `docs(opencode): add desktop access runbook`
  - Files: `README.md`, `DEPLOYMENT.md`
  - Pre-commit: `rg -n "opencode auth login|matt-desktop" README.md DEPLOYMENT.md`

- [x] 11. Verify cross-host config-output and build regression

  **What to do**:
  - Confirm that the shared extraction does not regress macbook output and that both host builds still succeed.
  - Compare the generated OpenCode config content before/after extraction where practical using `nix eval` or store-path comparisons.
  - Treat this as the build/regression gate before remote-access smoke testing.

  **Must NOT do**:
  - Do not skip macbook verification just because the feature target is `matt-desktop`.
  - Do not accept config drift without explicit rationale.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Regression verification across two hosts and generated config outputs.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `quick`: verification breadth is non-trivial.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: T12
  - **Blocked By**: T1, T2, T3, T4, T5

  **References**:
  - `hosts/macbook-pro-m2/home/home.nix:57` - Original generated config source.
  - `hosts/macbook-pro-m2/home/home.nix:78` - Original generated OMO config source.
  - `flake.nix:101` - Darwin system build target.
  - `flake.nix:149` - Desktop system build target.

  **Acceptance Criteria**:
  - [ ] Darwin build passes.
  - [ ] Desktop build passes.
  - [ ] Generated config content is unchanged on macbook except for approved path relocation.

  **QA Scenarios**:
  ```text
  Scenario: Both host builds pass
    Tool: Bash
    Preconditions: all build-affecting tasks complete
    Steps:
      1. Run `nix build .#darwinConfigurations.macbook-pro-m2.system`
      2. Run `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`
      3. Capture both outputs
    Expected Result: Both commands exit 0
    Failure Indicators: Any host fails evaluation or build
    Evidence: .sisyphus/evidence/task-11-both-builds.txt

  Scenario: Generated config remains stable
    Tool: Bash
    Preconditions: shared extraction complete
    Steps:
      1. Use `nix eval` or store-path inspection to compare generated OpenCode config for macbook before and after extraction
      2. Verify semantic parity of model/provider/plugin settings
    Expected Result: No unintended config drift
    Failure Indicators: Missing models/plugins/settings or changed semantics without justification
    Evidence: .sisyphus/evidence/task-11-config-parity.txt
  ```

  **Evidence to Capture**:
  - [ ] Combined build output
  - [ ] Config parity comparison output

  **Commit**: NO

- [ ] 12. Run desktop remote-access smoke checks and capture evidence

  **What to do**:
  - Verify the deployed desktop web UI end-to-end: service up, localhost auth challenge, Serve status, tailnet HTTPS reachability, and operator command usability.
  - Capture evidence that the default web UI path works before any alternative-client exploration begins.
  - Use this as the practical sign-off gate for the first milestone.

  **Must NOT do**:
  - Do not require manual iPhone tapping as acceptance.
  - Do not expand this task into full alternative-client evaluation.

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Multi-surface integration verification with service/network interplay.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `visual-engineering`: this is a smoke test, not frontend work.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: F1-F4
  - **Blocked By**: T6, T7, T8, T9, T10, T11

  **References**:
  - `hosts/matt-desktop/modules/opencode-web.nix` - Service behavior under test.
  - `justfile` - Operator commands added in T9.
  - `https://tailscale.com/docs/features/tailscale-serve` - Expected Serve semantics.

  **Acceptance Criteria**:
  - [ ] `systemctl status opencode-web` reports healthy service state.
  - [ ] Anonymous localhost request is challenged and authenticated request succeeds.
  - [ ] `tailscale serve status` and tailnet HTTPS endpoint both work.

  **QA Scenarios**:
  ```text
  Scenario: Happy path through tailnet-served OpenCode web
    Tool: Bash (curl)
    Preconditions: desktop service, password, and Tailscale Serve configured
    Steps:
      1. Run `systemctl status opencode-web --no-pager`
      2. Run `curl -u opencode:$OPENCODE_SERVER_PASSWORD -I http://127.0.0.1:4097`
      3. Run `curl -u opencode:$OPENCODE_SERVER_PASSWORD -k -I https://matt-desktop.tailc41cf5.ts.net`
      4. Run `tailscale serve status`
    Expected Result: Service is healthy, auth works, local and tailnet endpoints respond, Serve points at localhost backend
    Failure Indicators: Unit failure, 401 with valid creds, HTTPS connection failure, or Serve misconfiguration
    Evidence: .sisyphus/evidence/task-12-happy-path.txt

  Scenario: Failure path without credentials remains locked down
    Tool: Bash (curl)
    Preconditions: password-protected service active
    Steps:
      1. Run `curl -I http://127.0.0.1:4097`
      2. Run `curl -k -I https://matt-desktop.tailc41cf5.ts.net`
      3. Verify anonymous access does not receive a successful authenticated response
    Expected Result: Anonymous requests are rejected or challenged
    Failure Indicators: Anonymous access reaches the UI successfully
    Evidence: .sisyphus/evidence/task-12-auth-guard.txt
  ```

  **Evidence to Capture**:
  - [ ] Healthy service/status output
  - [ ] Authenticated and unauthenticated curl outputs
  - [ ] Serve status output

  **Commit**: NO

---

## Final Verification Wave

- [x] F1. **Plan Compliance Audit** - `oracle`
  Verify each deliverable exists: shared module, shared plugin pin file, macbook/shared wiring, desktop shared wiring, desktop app, desktop web service, Tailscale Serve, just commands, and docs. Reject any Portal refactor or ACL edits.

- [x] F2. **Code Quality Review** - `unspecified-high`
  Run `nix build .#darwinConfigurations.macbook-pro-m2.system`, `nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel`, and `nix flake check`. Review for dead paths, stale plugin-pin references, accidental hardcoded macOS paths in shared code, and secret leakage.

- [ ] F3. **Real Manual QA** - `unspecified-high`
  Replay every QA scenario from T1-T12, collect evidence into `.sisyphus/evidence/final-qa/`, and verify the desktop web path works with Tailscale Serve and password protection.

- [x] F4. **Scope Fidelity Check** - `deep`
  Confirm only OpenCode-related extraction, desktop install, desktop web service, Serve exposure, commands, and docs changed. Reject any unrelated desktop cleanup, Portal rewrite, ACL redesign, or reverse-proxy addition.

---

## Commit Strategy

- **1**: `refactor(opencode): extract shared core module` - add shared module and shared plugin-pin source
- **2**: `refactor(macbook): consume shared opencode core` - rewire macbook without changing Portal behavior
- **3**: `feat(desktop): add shared opencode core` - wire shared module into `matt-desktop` and install TUI
- **4**: `feat(desktop): add opencode desktop app` - add desktop app packaging/install path for Linux desktop
- **5**: `feat(desktop): add secure opencode web service` - add service, password/secret wiring, working directory prep
- **6**: `feat(desktop): publish opencode web over tailscale` - add Serve exposure and operator helpers
- **7**: `docs(opencode): add desktop access runbook` - document auth bootstrap, access flow, and deferred alternative-UI evaluation

---

## Success Criteria

### Verification Commands
```bash
nix build .#darwinConfigurations.macbook-pro-m2.system
nix build .#nixosConfigurations.matt-desktop.config.system.build.toplevel
nix flake check
tailscale serve status
curl -u opencode:$OPENCODE_SERVER_PASSWORD -k -I https://matt-desktop.tailc41cf5.ts.net
```

### Final Checklist
- [ ] Shared OpenCode core is host-agnostic
- [ ] Macbook still works with existing Portal path untouched
- [ ] matt-desktop has both OpenCode TUI and desktop app declaratively installed
- [ ] matt-desktop exposes default OpenCode web UI only through localhost + Tailscale Serve
- [ ] Anonymous access is challenged and authenticated access succeeds
- [ ] Alternative UI evaluation remains explicitly deferred
