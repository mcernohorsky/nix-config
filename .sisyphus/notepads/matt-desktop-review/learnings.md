# Learnings — matt-desktop-review

## Architecture
- `hosts/matt-desktop/` contains: `configuration.nix`, `home.nix`, `hardware-configuration.nix`, `disk-config.nix`, `modules/`
- Modules: `core.nix`, `nvidia.nix`, `hyprland.nix`, `gaming.nix`, `media.nix`
- Home Manager config is all in single `home.nix` (1536 lines)
- Deploy: `deploy-rs` over Tailscale OR `nixos-rebuild switch` locally
- Worktree: `/tmp/nix-config-matt-desktop-review` on branch `matt-desktop-review`

## Key Facts
- NVIDIA proprietary production drivers, modesetting enabled
- `hardware.nvidia.modesetting.enable = true` — this handles `nvidia-drm.modeset=1` kernel param automatically; do NOT add it to kernelParams
- Hyprland UWSM: `programs.hyprland.withUWSM = true` system-side + `wayland.windowManager.hyprland.systemd.enable = false` HM-side — correct pairing
- Stylix handles theming; `stylix.targets.hyprlock.enable = false` is intentional (hyprlock is hand-themed)
- Single monitor setup
- User is `matt`, home is `/home/matt`

## NVIDIA kernel params (final state after dedup)
Should all live in `nvidia.nix` only:
- `plymouth.use-simpledrm` (already there)
- `nvidia_drm.fbdev=1` (currently duplicated in core.nix:114 AND nvidia.nix:17)
- `nvidia.NVreg_PreserveVideoMemoryAllocations=1` (currently in core.nix:113 only — move to nvidia.nix)
- `nvidia.NVreg_RegistryDwords=RMUseEnterpriseDdc=1` (NEW — add to nvidia.nix for DDC/CI)
- `nvidia-drm.modeset=1` — DO NOT ADD; handled by `modesetting.enable = true`

## ddcutil setup (Task 6)
Must add to nvidia.nix:
- `hardware.i2c.enable = true` (creates i2c group + udev rules)
- `boot.kernelModules = [ "i2c-dev" "i2c-nvidia-gpu" ]`
- `ddcutil` to `environment.systemPackages`
Must add to configuration.nix:
- `"i2c"` to `users.users.matt.extraGroups`

## hypridle DDC commands (Task 7)
- Display standby: `ddcutil setvcp 0xD6 4`
- Display on: `ddcutil setvcp 0xD6 1`
- Single monitor — no need for `--bus N` targeting

## Nix formatting conventions
- 2-space indentation
- Comments: `# Comment` style
- Section headers in home.nix: `# ===================` with `# Section Title` and another `# ===================`
- All file content follows existing patterns closely

## NixOS eval command (for verification)
```bash
nix eval /tmp/nix-config-matt-desktop-review#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build
```
