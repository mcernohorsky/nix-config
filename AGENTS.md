# Agent notes

## Evaluation and deployment

- After pushing, pull `~/.config/nix-config` on `matt-desktop` over Tailscale SSH so both checkouts stay in sync; verify with `git log --oneline -1` on each side.
- Do not evaluate `nixosConfigurations.matt-desktop.config` on macOS; full desktop evaluation can consume many GB of RAM. Use small flake attributes or `.options`, or inspect/build on `matt-desktop` over SSH.
- Deploy through the `just` recipes. Oracle builds use Determinate's native Linux builder; desktop builds run on `matt-desktop` through deploy-rs. OrbStack is not a deployment backend.
- `just deploy-desktop` activates live and checks whether a reboot is advisable. Report its warning to the user. A kernel change or failed `nvidia-smi` indicates reboot; NVIDIA mismatches affect GPU consumers, while Tailscale/SSH should remain available. The deploying agent is authorized to reboot matt-desktop itself (`tailscale ssh matt@matt-desktop.tailc41cf5.ts.net sudo reboot`) when the check advises it.
