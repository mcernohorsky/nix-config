# Agent notes

- Deploy only through the `just` recipes (see DEPLOYMENT.md). OrbStack is not a deployment backend.
- Do not evaluate `nixosConfigurations.matt-desktop.config` on macOS, because it uses many GB of RAM. Build it on `matt-desktop` instead.
- Report `just deploy-desktop`'s reboot warning. When it advises a reboot, you may reboot the desktop yourself with `tailscale ssh matt@matt-desktop.tailc41cf5.ts.net sudo reboot`.
- After pushing, pull `~/.config/nix-config` on the other workstation and compare `git log --oneline -1` on both.
