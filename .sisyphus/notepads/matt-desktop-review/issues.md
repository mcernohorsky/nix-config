# Issues — matt-desktop-review

## Known Issues / Gotchas

### NVIDIA + modesetting.enable
`hardware.nvidia.modesetting.enable = true` automatically injects `nvidia-drm.modeset=1` into kernel params via the NixOS module. Do NOT manually add this to `boot.kernelParams` — it would be a duplicate.

### NixOS list merging
`boot.kernelParams` is a list — NixOS MERGES lists from multiple modules. Moving params from core.nix to nvidia.nix is safe; they get combined in the final config.

### Avahi openFirewall removal
Removing `openFirewall = true` from Avahi is safe because with `allowInterfaces = ["enp4s0"]`, Avahi only binds to that interface. The firewall rule would only matter if Avahi tried to bind to other interfaces.

### ddcutil and SSH sessions
`ddcutil setvcp 0xD6 4` sends monitor to standby but SSH session stays alive. The on-resume command `ddcutil setvcp 0xD6 1` runs when hypridle detects activity (input events still reach the system even with display off).

### home.nix line numbers
Line numbers in the plan are from the ORIGINAL file. After Task 1 edits, lines shift. Always grep/search rather than jumping to a specific line number when implementing subsequent tasks.

### nix eval in worktree
Run from the worktree directory (`/tmp/nix-config-matt-desktop-review`):
```bash
nix eval .#nixosConfigurations.matt-desktop.config.system.build.toplevel --no-build 2>&1 | tail -5
```
