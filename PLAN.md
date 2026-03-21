# Determinate Migration Plan

This file is the working engineering plan for migration tasks and blockers.
`DEPLOYMENT.md` remains focused on reproducible bring-up/deployment instructions.

## 0) Current Status (Mar 2026)

### Completed

- `macbook-pro-m2` migrated to Determinate Nix and verified.
- `matt-desktop` migrated to Determinate Nix and verified.
- `oracle-0` migrated to Determinate Nix and verified.
- Oracle Grafana blocker fixed by adding required explicit secret key via agenix.
- Oracle deploy path (`just deploy-oracle`) fixed for Docker-based deploy-rs by adding Determinate cache substituter/key to the Docker `NIX_CONFIG`.

### Still Important

- Keep dirty-tree warnings visible (do not suppress `warning: Git tree ... is dirty`).
- Keep this plan file updated as handoff source-of-truth.

## 1) Key Learnings and Root Causes

### A) Grafana NixOS 26.05 assertion (resolved)

`oracle-0` evaluation failed because NixOS 26.05 now asserts:

- `services.grafana.settings.security.secret_key != null`

Fix implemented:

- Added `secrets/grafana-secret-key.age`
- Added `age.secrets.grafana-secret-key` on Oracle
- Wired Grafana to file provider:
  - `services.grafana.settings.security.secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";`

### B) Determinate build failures in Docker deploy flow (resolved)

When Oracle Determinate module was enabled, Docker deploy attempted to build Determinate Nix from source and failed in `nix-functional-tests`.

Observed failure pattern:

- `error: executing '/nix/store/...-busybox': No such file or directory`
- repeated in `build-remote-*`, `local-overlay-store`, and related functional tests.

Root cause in practice:

- Docker deploy environment lacked Determinate binary cache config, so source build path was taken.
- Source path hit known-fragile functional tests in containerized/restricted contexts.

Reliable fix implemented:

- Add Determinate substituter/key to Docker `NIX_CONFIG` used by `just deploy-oracle`:
  - substituter: `https://install.determinate.systems`
  - key: `cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=`

Result:

- Determinate package fetched from cache instead of source-building tests.
- `just deploy-oracle` succeeds again with Determinate enabled.

## 2) Current Host Snapshot

### macbook-pro-m2

- Determinate Nix active
- Flake includes `inputs.determinate.darwinModules.default`
- Uses `eval-cores = 0`

### matt-desktop

- Determinate Nix active
- Flake includes `inputs.determinate.nixosModules.default`
- Uses `eval-cores = 0`
- Home Manager keeps `nix.package = lib.mkForce null`

### oracle-0

- Determinate Nix active
- `nix --version` reports Determinate Nix 3.17.1
- `determinate-nixd version` available and reports 3.17.1
- `nix-daemon.service` active via determinate wrapper process chain
- Core services verified active: Grafana, Prometheus, Caddy, repertoire-builder container
- App endpoint verification succeeded (`chess.cernohorsky.ca` backend + frontend versions)
- `eval-cores = 1` chosen as conservative production default (parallel eval disabled)

## 3) Important Configuration Decisions

### eval-cores policy

- `eval-cores` controls Nix expression evaluation parallelism, not builder VM sizing.
- Determinate semantics (from docs):
  - `0`: all cores
  - `1`: disable parallel eval
  - `2+`: fixed number of eval threads
- Oracle decision: keep `eval-cores = 1` for predictable production behavior.

### Cache policy for Docker deploy

- `just deploy-oracle` now injects Determinate cache settings into container `NIX_CONFIG`.
- This must remain in place until native Linux builder rollout is universally available/reliable.

### Flake-level cache policy

- `flake.nix` `nixConfig` now includes:
  - `https://install.determinate.systems`
  - key `cache.flakehub.com-3:...`

## 4) Remaining Work / Open Follow-ups

1. **Optional cleanup:** investigate `determinate-nixd.socket` unit state on Oracle (`inactive` while `nix-daemon` is active via determinate wrapper). This does not currently block operation.
2. **Optional hardening:** decide whether to add Determinate cache settings directly in system-level `nix.settings` for all hosts (in addition to flake/docker path).
3. **Optional simplification later:** when Determinate native Linux builder is broadly available and stable, reassess need for Docker deploy path for Oracle.
4. Keep monitoring Oracle `/boot` capacity after prior cleanup; current state is healthy.

## 5) Practical Command Checklist

Deploy Oracle:

```bash
just deploy-oracle
```

Verify Oracle Determinate runtime:

```bash
ssh matt@oracle-0.tailc41cf5.ts.net "nix --version"
ssh matt@oracle-0.tailc41cf5.ts.net "determinate-nixd version"
ssh matt@oracle-0.tailc41cf5.ts.net "systemctl status nix-daemon --no-pager"
```

Verify app health:

```bash
curl -fsS https://chess.cernohorsky.ca/api/version
curl -fsS https://chess.cernohorsky.ca/version.json
```

## 6) Handoff Notes for Next Agent

- Do not remove dirty-tree warnings from deploy output.
- Preserve `PLAN.md` updates during future migration work.
- If Docker deploy starts source-building Determinate again, first confirm cache config is still present in `justfile` and flake `nixConfig`.
