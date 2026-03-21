# nix-config — notes for AI / editor tooling

## Do not evaluate full NixOS `config` on macOS

Commands like:

```bash
nix eval '.#nixosConfigurations.matt-desktop.config.home-manager.extraSpecialArgs'
nix eval '.#nixosConfigurations.matt-desktop.config....'
```

force a **full** instantiation of the Linux desktop system (modules, HM, etc.) and can consume **many GB of RAM** and CPU for a long time on an Apple Silicon Mac. This is not a daemon leak — it is the cost of evaluating `config`.

**Prefer instead:**

- **Option metadata (lighter):** `nix eval '.#nixosConfigurations.matt-desktop.options...'` or use `nix repl` / `nixos-option` on the target host.
- **Inspect on the machine:** SSH to `matt-desktop` and run `nixos-rebuild dry-build`, `nix eval` there, or read the deployed closure.
- **Small attributes:** avoid drilling into `config` unless necessary; prefer flake `checks`, `packages`, or module `options` for tooling.

The workspace [`.vscode/settings.json`](.vscode/settings.json) points **nixd** at **`.options`** and flake **nixpkgs** so the language server does not need `config` for completions.

## OpenCode (shared Home Manager module)

`modules/home/opencode-core.nix` is imported by both **macbook-pro-m2** and **matt-desktop** home configs with `modules.home.opencodeCore.enable = true` only — there are no per-host overrides for plugins or models, so behavior matches.

Plugins are **npm version pins** in [`modules/home/opencode-plugins.json`](modules/home/opencode-plugins.json), rendered as `name@version` in `programs.opencode.settings.plugin` (Home Manager writes `~/.config/opencode/opencode.json`). That is the reproducible Nix-side pattern; OpenCode still fetches plugin packages into its cache at runtime.

**Auth for Cursor models:** after deploy, run `opencode auth login --provider cursor` ([opencode-cursor-oauth](https://github.com/ephraimduncan/opencode-cursor)).

**Bun vs Node:** this module puts **Bun** on PATH. The Cursor plugin still **spawns a child `node` process** for `h2-bridge.mjs` (hardcoded upstream because `node:http2` was unreliable under Bun). Both **macbook** and **matt-desktop** home configs install `pkgs.nodejs` so `node` is on PATH for that bridge (and `#!/usr/bin/env node` scripts).

**Replacing oh-my-opencode:** the old stack bundled many **named agents**, **categories**, **hooks**, and optional **MCP** wiring. Native OpenCode + Home Manager now covers:

- **Agents / skills / commands:** `programs.opencode.{agents,skills,commands}` in `opencode-core.nix` or per-host `home.nix` (see `home-manager` `programs.opencode` options).
- **MCP:** `opencode-core.nix` registers [Exa](https://exa.ai/docs/reference/exa-mcp) (`mcp.exa` remote); `tools` disables Exa globally and the **explore** agent re-enables `exa_*` only. Add `?exaApiKey=…` to the URL if you need higher rate limits.

If you relied on a specific OMO agent (e.g. Sisyphus-style presets), port those into `opencode/agent/*.md` or `programs.opencode.agents` with the models you want (e.g. Cursor via the plugin, or other providers).
