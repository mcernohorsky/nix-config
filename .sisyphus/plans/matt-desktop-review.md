# Plan: matt-desktop NixOS Configuration Review & Cleanup

## Objective
Full review and cleanup of the matt-desktop NixOS configuration. Primary goal: fix the display-not-turning-off issue using ddcutil (DDC/CI). Secondary: clean up ~10 issues found during audit (deprecated options, duplicates, broken settings, redundancies).

## Context
- **System**: NixOS x86_64-linux, Hyprland compositor, NVIDIA proprietary drivers (production)
- **Primary issue**: Display goes to lock screen (hyprlock) but never turns off. Root cause: `hyprctl dispatch dpms off` is a known broken path on NVIDIA proprietary drivers.
- **Solution**: Replace DPMS commands with ddcutil (DDC/CI) which talks directly to the monitor over I2C, bypassing the NVIDIA driver entirely.
- **Monitor setup**: Single monitor
- **Deploy method**: `deploy-rs` over Tailscale from macbook-pro-m2, OR local `nixos-rebuild switch`

## Key Decisions Made
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Display off strategy | ddcutil (DDC/CI) | Machine stays running (Jellyfin, downloads); NVIDIA DPMS is broken |
| Avahi consolidation | Samba-only on enp4s0 | User doesn't need general mDNS right now; remove misleading comments |
| direct_scanout | Remove | Risky on NVIDIA, no known benefit, user hasn't noticed it helping |
| brightnessctl | Remove package + bindings | Laptop-only tool, completely non-functional on desktop monitor |
| Security (Samba/restic) | Keep as-is | User confirms intentional tradeoffs, out of scope |
| Sudo NOPASSWD ALL | Keep (deploy-rs needs it) | Consolidate by removing overridden restricted rules |

## Architecture / Patterns to Follow
- **Nix formatting**: `# Comment` prefix, consistent 2-space indentation
- **home.nix sections**: Delimited by `# ===================` separators
- **NVIDIA config**: ALL NVIDIA-related kernel params belong in `nvidia.nix` (single source of truth)
- **Avahi config**: Consolidate into `configuration.nix` (has Samba-specific bits)
- **Module merging**: NixOS merges list attrs (kernelParams, extraGroups) across modules — safe to split across files

## Deployment Strategy
**Two-phase deployment** to minimize risk:
- **Phase 1** (Commits 1-4): Pure cleanup — no new dependencies, no behavior changes. Deploy and verify system still works.
- **Phase 2** (Commits 5-6): ddcutil setup + hypridle fix. Deploy, then run I2C/DDC verification walkthrough.

## Constraints
- MUST NOT touch: Samba configuration, restic configuration, Tailscale configuration
- MUST NOT add new env vars when removing broken ones (no scope creep)
- MUST NOT restructure file organization beyond what's needed for dedup
- MUST preserve all NVIDIA kernel params (only deduplicate, never remove)
- MUST keep deploy-rs NOPASSWD ALL sudo rule functional

---

## Tasks

- [x] Task 1: Remove deprecated Hyprland options and fix broken keybinding
- [x] Task 2: Remove GDK_SCALE and direct_scanout
- [x] Task 3: Deduplicate NVIDIA kernel params into nvidia.nix
- [x] Task 4: Consolidate Avahi configuration
- [x] Task 5: Consolidate sudo rules
- [x] Task 6: Set up ddcutil for DDC/CI monitor control
- [x] Task 7: Fix hypridle — replace broken DPMS/brightnessctl with ddcutil
- [x] Task 8: Post-deploy verification and I2C walkthrough

## Task 1: Remove deprecated Hyprland options and fix broken keybinding

**File**: `hosts/matt-desktop/home.nix`

### Changes

**1a. Remove deprecated `new_optimizations`** (line 90)
```nix
# REMOVE this line:
new_optimizations = true;
```
This option was deprecated in recent Hyprland versions. The optimization is always on now.

**1b. Fix `togglesplit` keybinding** (line 168)
```nix
# BEFORE (broken — togglesplit was removed as a dispatcher in Hyprland 0.54):
"$mainMod, T, togglesplit,"

# AFTER:
"$mainMod, T, layoutmsg, togglesplit"
```
The `togglesplit` dispatcher was removed. It's now a `layoutmsg` argument. This keybinding is currently silently broken (does nothing).

**1c. Remove redundant nushell from home.packages** (line 1395)
```nix
# REMOVE this line from home.packages:
nushell
```
`programs.nushell.enable = true` (line 1169) already installs nushell. Having it in `home.packages` too is redundant.

### QA
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` succeeds
- `grep -n "new_optimizations" hosts/matt-desktop/home.nix` returns no matches
- `grep -n "togglesplit" hosts/matt-desktop/home.nix` shows `layoutmsg, togglesplit` (not bare `togglesplit,`)
- `grep -n "nushell" hosts/matt-desktop/home.nix` shows only `programs.nushell` references, no `home.packages` entry

---

## Task 2: Remove GDK_SCALE and direct_scanout

**File**: `hosts/matt-desktop/home.nix`

### Changes

**2a. Remove `GDK_SCALE,1.5` from env** (line 62)
```nix
# REMOVE this line from env = [...]:
"GDK_SCALE,1.5"
```
`GDK_SCALE` only accepts integer values. Setting `1.5` is silently truncated to `1` or ignored. GTK4 apps already respect Hyprland's fractional scale via `wp_fractional_scale_v1`. Hyprland's own `monitor = ",preferred,auto,1.5"` handles scaling.

**2b. Remove `direct_scanout = true`** (lines 77-79)
```nix
# REMOVE the entire render block:
render = {
  direct_scanout = true;
};
```
On NVIDIA, direct scanout can cause flickering, black screens in fullscreen apps, and tearing. The default (false) is safer. No observed benefit from having it enabled.

### QA
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` succeeds
- `grep -n "GDK_SCALE" hosts/matt-desktop/home.nix` returns no matches
- `grep -n "direct_scanout" hosts/matt-desktop/home.nix` returns no matches

---

## Task 3: Deduplicate NVIDIA kernel params into nvidia.nix

**File**: `hosts/matt-desktop/modules/core.nix` and `hosts/matt-desktop/modules/nvidia.nix`

### Context
Three NVIDIA kernel params are set in `core.nix` (lines 112-114) that belong in `nvidia.nix`:
- `nvidia-drm.modeset=1` — duplicated (nvidia.nix has `modesetting.enable = true` which sets this)
- `nvidia.NVreg_PreserveVideoMemoryAllocations=1` — NVIDIA-specific, belongs in nvidia.nix
- `nvidia_drm.fbdev=1` — duplicated in both core.nix:114 AND nvidia.nix:17

### Changes

**3a. Remove NVIDIA params from core.nix boot.kernelParams** (lines 111-114)
Remove these three lines from `core.nix`'s `boot.kernelParams`:
```nix
# REMOVE from core.nix:
"nvidia-drm.modeset=1"
"nvidia.NVreg_PreserveVideoMemoryAllocations=1"
"nvidia_drm.fbdev=1"
```
Keep the remaining non-NVIDIA params (`quiet`, `splash`, `loglevel=3`, etc.) in core.nix.

**3b. Ensure nvidia.nix has all three params**
Verify/update `nvidia.nix` `boot.kernelParams` (currently line 15-18) to contain:
```nix
boot.kernelParams = [
  "plymouth.use-simpledrm"
  "nvidia_drm.fbdev=1"
  # Preserve video memory across suspend/resume
  "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
];
```
Note: `nvidia-drm.modeset=1` does NOT need to be in kernelParams because `hardware.nvidia.modesetting.enable = true` (line 29) already handles this via the NixOS module.

### QA
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` succeeds
- `grep -rn "nvidia_drm.fbdev" hosts/matt-desktop/` returns exactly ONE match in `nvidia.nix`
- `grep -rn "NVreg_Preserve" hosts/matt-desktop/` returns exactly ONE match in `nvidia.nix`
- `grep -rn "nvidia-drm.modeset" hosts/matt-desktop/` returns NO matches (handled by `modesetting.enable`)

---

## Task 4: Consolidate Avahi configuration

**Files**: `hosts/matt-desktop/modules/core.nix` and `hosts/matt-desktop/configuration.nix`

### Context
Avahi is configured in two places:
- `core.nix:43-52` — general mDNS with `openFirewall = true`, `nssmdns4 = true`, publishing addresses/workstation. Comment says "find printers, chromecast" but `allowInterfaces = ["enp4s0"]` from configuration.nix restricts it to only direct ethernet.
- `configuration.nix:176-194` — Samba-specific with `allowInterfaces = ["enp4s0"]`, Samba service advertisement.

**Decision**: Consolidate into `configuration.nix` as Samba-only on enp4s0. User doesn't need general mDNS right now.

### Changes

**4a. Remove Avahi block from core.nix** (lines 42-52)
Remove the entire block:
```nix
# REMOVE from core.nix:
# Avahi for mDNS
services.avahi = {
  enable = true;
  nssmdns4 = true;
  openFirewall = true;
  publish = {
    enable = true;
    addresses = true;
    workstation = true;
  };
};
```
Also remove the comment at lines 35-37:
```nix
# REMOVE:
# mDNS/DNS-SD for local network discovery
# (find printers, chromecast, etc.)
```

**4b. Update Avahi in configuration.nix** (lines 175-194)
Add `nssmdns4 = true` (was only in core.nix) and update the comment:
```nix
# Avahi: mDNS for Samba discovery from macOS Finder (enp4s0 only)
# NOTE: Restricted to direct ethernet link. For general mDNS (printers, Chromecast),
# remove allowInterfaces or add your main network interface.
services.avahi = {
  enable = true;
  nssmdns4 = true;
  allowInterfaces = [ "enp4s0" ];
  publish = {
    enable = true;
    userServices = true;
  };
  extraServiceFiles.smb = ''
    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
      <name replace-wildcards="yes">%h</name>
      <service>
        <type>_smb._tcp</type>
        <port>445</port>
      </service>
    </service-group>
  '';
};
```
Note: Removed `openFirewall = true` (unnecessary when restricted to one interface), removed `addresses = true` and `workstation = true` (not needed for Samba-only use).

### QA
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` succeeds
- `grep -rn "services.avahi" hosts/matt-desktop/` returns matches in ONE file only (`configuration.nix`)
- `grep -rn "chromecast" hosts/matt-desktop/` returns no matches (misleading comment removed)

---

## Task 5: Consolidate sudo rules

**Files**: `hosts/matt-desktop/modules/core.nix` and `hosts/matt-desktop/configuration.nix`

### Context
- `core.nix:138-150`: Sets `wheelNeedsPassword = true` and adds limited NOPASSWD for `nixos-rebuild` and `systemctl`
- `configuration.nix:106-113`: Grants `NOPASSWD: ALL` for user matt (needed for deploy-rs)

The `NOPASSWD: ALL` in configuration.nix completely overrides the careful restrictions in core.nix, making them misleading dead code.

### Changes

**5a. Remove redundant sudo extraRules from core.nix** (lines 141-149)
```nix
# REMOVE from core.nix:
extraRules = [
  {
    groups = [ "wheel" ];
    commands = [
      { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
    ];
  }
];
```
Keep `security.sudo.enable = true` and `wheelNeedsPassword = true` in core.nix.

**5b. Add explanatory comment to configuration.nix sudo block** (lines 105-113)
```nix
# Passwordless sudo for matt
# Required by deploy-rs for remote NixOS activation.
# This overrides wheelNeedsPassword from core.nix for user matt specifically.
security.sudo.extraRules = [
  {
    users = [ "matt" ];
    commands = [
      { command = "ALL"; options = [ "NOPASSWD" ]; }
    ];
  }
];
```

### QA
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` succeeds
- `grep -rn "extraRules" hosts/matt-desktop/` returns matches only in `configuration.nix`
- `grep -rn "nixos-rebuild.*NOPASSWD" hosts/matt-desktop/` returns no matches (removed from core.nix)

---

## Task 6: Set up ddcutil for DDC/CI monitor control

**Files**: `hosts/matt-desktop/modules/nvidia.nix` and `hosts/matt-desktop/configuration.nix`

### Changes

**6a. Enable I2C hardware support in nvidia.nix**
Add to `nvidia.nix`:
```nix
# I2C/DDC for direct monitor control (ddcutil)
# Required because NVIDIA's DPMS path is unreliable under Wayland
hardware.i2c.enable = true;

boot.kernelModules = [ "i2c-dev" "i2c-nvidia-gpu" ];
```
Note: `hardware.i2c.enable = true` automatically creates the `i2c` group and sets up udev rules. The `i2c-nvidia-gpu` module provides I2C access through NVIDIA GPUs specifically.

**6b. Add ddcutil to system packages in nvidia.nix**
Add `ddcutil` to the existing `environment.systemPackages`:
```nix
environment.systemPackages = with pkgs; [
  nvidia-vaapi-driver
  libva-utils
  vulkan-tools
  mesa-demos
  ddcutil  # Direct monitor control via DDC/CI (used by hypridle)
];
```

**6c. Add NVIDIA DDC/CI kernel param in nvidia.nix**
Add to the existing `boot.kernelParams`:
```nix
boot.kernelParams = [
  "plymouth.use-simpledrm"
  "nvidia_drm.fbdev=1"
  "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  # Enable enterprise DDC for reliable I2C access on NVIDIA GPUs
  "nvidia.NVreg_RegistryDwords=RMUseEnterpriseDdc=1"
];
```

**6d. Add i2c group to user in configuration.nix** (line 29)
```nix
# BEFORE:
extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];

# AFTER:
extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "i2c" ];
```

### QA
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` succeeds
- `grep -n "i2c" hosts/matt-desktop/modules/nvidia.nix` shows `hardware.i2c.enable`, kernel modules, and group
- `grep -n "ddcutil" hosts/matt-desktop/modules/nvidia.nix` shows package entry
- `grep -n "i2c" hosts/matt-desktop/configuration.nix` shows group in extraGroups

---

## Task 7: Fix hypridle — replace broken DPMS/brightnessctl with ddcutil

**Files**: `hosts/matt-desktop/home.nix` and `hosts/matt-desktop/modules/hyprland.nix`

### Context
Current hypridle has three listeners:
1. **25min dim** (lines 398-403): Uses `brightnessctl` — non-functional on desktop monitors
2. **30min lock** (lines 404-407): Uses `loginctl lock-session` — working correctly
3. **60min display off** (lines 408-412): Uses `hyprctl dispatch dpms off` — broken on NVIDIA

### Changes

**7a. Replace the hypridle listeners in home.nix** (lines 398-413)
Replace the entire `listener` block with:
```nix
listener = [
  {
    timeout = 1800; # 30 min - lock
    on-timeout = "loginctl lock-session";
  }
  {
    # 60 min - monitor off via DDC/CI (bypasses broken NVIDIA DPMS path)
    # DDC/CI feature code 0xD6: Power Mode
    # Values: 1=on, 4=standby, 5=off
    timeout = 3600;
    on-timeout = "ddcutil setvcp 0xD6 4";
    on-resume = "ddcutil setvcp 0xD6 1";
  }
];
```
Changes:
- **Removed** the 25min brightnessctl dim listener entirely (non-functional on desktop)
- **Replaced** `hyprctl dispatch dpms off/on` with `ddcutil setvcp 0xD6 4/1` (standby/on)
- **Kept** the 30min lock listener unchanged

**7d. Update `after_sleep_cmd` in hypridle general section** (line 396)
The `general` block still references `hyprctl dispatch dpms on` for wake-from-suspend. Update for consistency:
```nix
general = {
  lock_cmd = "pidof hyprlock || hyprlock --grace 3";
  before_sleep_cmd = "loginctl lock-session";
  # Wake monitor via DDC/CI after suspend (consistent with ddcutil idle approach)
  after_sleep_cmd = "ddcutil setvcp 0xD6 1";
};
```
Note: DPMS *on* typically works even on NVIDIA, but using ddcutil here keeps the display power management consistent through a single mechanism.

**7b. Remove brightnessctl from hyprland.nix packages** (line 86)
```nix
# REMOVE from environment.systemPackages:
brightnessctl
```

**7c. Remove brightness media key bindings from home.nix** (lines 252-253)
```nix
# REMOVE these two lines from bindel:
", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
```
Desktop monitors don't have backlight controls. These keys do nothing.

### QA
- `nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build` succeeds
- `grep -rn "brightnessctl" hosts/matt-desktop/` returns NO matches
- `grep -n "dpms off" hosts/matt-desktop/home.nix` returns NO matches
- `grep -n "ddcutil" hosts/matt-desktop/home.nix` returns matches in hypridle listener
- `grep -n "XF86MonBrightness" hosts/matt-desktop/home.nix` returns NO matches

---

## Task 8: Post-deploy verification and I2C walkthrough

This task runs AFTER deploying the changes to matt-desktop. It verifies all changes took effect and walks through enabling DDC/CI.

### Phase 1 Verification (after deploying Tasks 1-5)

Run from macbook (or locally on matt-desktop):
```bash
# Verify config built and deployed successfully
ssh matt@matt-desktop.tailc41cf5.ts.net "nixos-version"

# Verify kernel params (nvidia params deduplicated, no duplicates)
ssh matt@matt-desktop.tailc41cf5.ts.net "cat /proc/cmdline | tr ' ' '\n' | grep nvidia"
# Expected: nvidia_drm.fbdev=1 appears ONCE
#           NVreg_PreserveVideoMemoryAllocations=1 appears ONCE
#           nvidia-drm.modeset=1 does NOT appear (handled by modesetting.enable)

# Verify Hyprland binds updated
ssh matt@matt-desktop.tailc41cf5.ts.net "hyprctl binds 2>/dev/null | grep -A3 togglesplit"
# Expected: dispatcher is "layoutmsg", arg is "togglesplit"

# Verify no GDK_SCALE
ssh matt@matt-desktop.tailc41cf5.ts.net "env | grep GDK_SCALE"
# Expected: no output
```

### Phase 2 Verification (after deploying Tasks 6-7)

**Step 1: Verify I2C modules loaded**
```bash
ssh matt@matt-desktop.tailc41cf5.ts.net "lsmod | grep i2c"
# Expected: i2c_dev and i2c_nvidia_gpu in output
```

**Step 2: Verify user in i2c group**
```bash
ssh matt@matt-desktop.tailc41cf5.ts.net "groups matt"
# Expected: 'i2c' appears in group list
# NOTE: User may need to log out and back in for group change to take effect
```

**Step 3: Detect monitors via DDC/CI**
```bash
ssh matt@matt-desktop.tailc41cf5.ts.net "ddcutil detect"
# Expected: At least 1 display found with I2C bus info
# If "No displays found", run: ddcutil environment
# and check if DDC/CI is enabled in monitor OSD settings
```

**Step 4: Test power control (safe — sends "on" command)**
```bash
ssh matt@matt-desktop.tailc41cf5.ts.net "ddcutil setvcp 0xD6 1"
# Expected: exit code 0, no error (sends "power on" — safe no-op if already on)
```

**Step 5: Test standby (monitor will turn off!)**
```bash
# WARNING: This will put the monitor in standby. Move mouse to wake.
ssh matt@matt-desktop.tailc41cf5.ts.net "ddcutil setvcp 0xD6 4"
# Expected: monitor enters standby
# Then move mouse or press key — monitor should wake automatically
# If not, run: ddcutil setvcp 0xD6 1  (or the monitor's physical power button)
```

**Step 6: Verify hypridle config**
```bash
ssh matt@matt-desktop.tailc41cf5.ts.net "cat ~/.config/hypr/hypridle.conf"
# Expected: contains "ddcutil", does NOT contain "brightnessctl" or "dpms off"
```

### Troubleshooting: If ddcutil detect fails

1. **Check if DDC/CI is enabled in monitor OSD**: Most monitors have this under Settings > OSD > DDC/CI. It must be ON.
2. **Check I2C devices exist**: `ls /dev/i2c-*` — should show multiple devices
3. **Run full environment check**: `ddcutil environment` — shows all I2C buses and which are usable
4. **Check NVIDIA DDC param**: `cat /sys/module/nvidia/parameters/NVreg_RegistryDwords` — should contain `RMUseEnterpriseDdc=1`
5. **Try without i2c-nvidia-gpu**: Some setups work with just `i2c-dev`. If `i2c-nvidia-gpu` causes issues, remove it.
6. **DisplayPort vs HDMI**: DisplayPort + NVIDIA can be pickier for DDC/CI. Try HDMI if DP doesn't work.
7. **Fallback**: If DDC/CI absolutely won't work with your monitor, replace the ddcutil commands with `systemctl suspend` instead.

---

## Final Verification Wave

After all tasks are complete and deployed:

```bash
# Full verification script — run on matt-desktop
echo "=== Kernel Params ===" && cat /proc/cmdline | tr ' ' '\n' | sort
echo "=== I2C Modules ===" && lsmod | grep i2c
echo "=== User Groups ===" && groups matt
echo "=== DDC Detect ===" && ddcutil detect 2>&1 | head -10
echo "=== Hyprland Version ===" && hyprctl version 2>/dev/null | head -3
echo "=== Hypridle Config ===" && grep -E "(ddcutil|brightnessctl|dpms)" ~/.config/hypr/hypridle.conf
echo "=== Environment ===" && env | grep -E "(GDK_SCALE|LIBVA|NVD_BACKEND)"
```

Expected results:
- `nvidia_drm.fbdev=1` appears once
- `i2c_dev` and `i2c_nvidia_gpu` modules loaded
- `i2c` in user groups
- At least 1 DDC display detected
- Hypridle mentions `ddcutil`, NOT `brightnessctl` or `dpms`
- No `GDK_SCALE` in environment

---

## Security Commentary (informational, no changes)

Per user request, these are NOT being changed, but for awareness:

**Samba root share (`/`)**: The Samba config shares the entire root filesystem as writable with `force_user = matt`. While restricted to link-local addresses (`169.254.x.x` and `fe80::/10`), this means any device on the direct ethernet cable has full filesystem write access as matt. The `force_user` acts as implicit authentication (all operations run as matt regardless of who connects). There's no SMB password configured. Risk is low because: (a) link-local only works on the direct cable, (b) the cable connects to a trusted MacBook. But if the ethernet port were ever connected to a network with other devices, this would be a significant exposure.

**Restic REST server (`--no-auth`)**: The restic backup server has no authentication. It's restricted by: (a) Tailscale ACLs (only `tag:cloud` can reach it), (b) `appendOnly = true` (can't delete backups), (c) firewall only opens port 8000 on `tailscale0`. This is a reasonable defense-in-depth tradeoff — Tailscale provides the auth layer. The `--no-auth` simplifies the oracle-0 backup job. Acceptable.

**Sudo NOPASSWD ALL**: Required for deploy-rs remote activation. The alternative would be a more targeted sudoers rule allowing only `/nix/store/*/bin/switch-to-configuration`, but deploy-rs doesn't support this granularity cleanly.
