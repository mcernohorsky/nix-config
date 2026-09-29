# Agent notes

- Deploy only through the `just` recipes (see DEPLOYMENT.md). OrbStack is not a deployment backend.
- Do not evaluate `nixosConfigurations.matt-desktop.config` on macOS, because it uses many GB of RAM. Build it on `matt-desktop` instead.
- Report `just deploy-desktop`'s reboot warning. When it advises a reboot, you may reboot the desktop yourself with `tailscale ssh matt@matt-desktop.tailc41cf5.ts.net sudo reboot`.
- Use Jujutsu (`jj`) for version control. Keep all configuration work on the single `main` bookmark; do not create side branches or stashes unless requested.
- Review `jj status` and `jj diff`, then use `jj commit -m '<description>'` and `jj bookmark set main -r @-`. Run `nix develop -c just sync` to push and update the other workstation. The recipe refuses to overwrite unpublished work.
- After syncing, verify the `main` commit ID and clean working copies on both hosts. The colocated Git repository remains available for Nix, GitHub, and tools that require it.
