{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.opencodeV2;

  # Prints the unpacked extension directory for the bun-global install.
  # Upstream documents `npm root --global`, which does not apply to the
  # bun + Nix layout used here (~/.bun/install/global/...).
  browser-control-extension-path = pkgs.writeShellApplication {
    name = "browser-control-extension-path";
    text = ''
      ext="$HOME/.bun/install/global/node_modules/@opencode-ai/browser-control/extension/dist"
      printf '%s\n' "$ext"
      if [ ! -f "$ext/manifest.json" ]; then
        echo "browser-control-extension-path: extension not found at $ext (run: bun install -g --trust @opencode-ai/browser-control)" >&2
        exit 1
      fi
    '';
  };
in
{
  options.modules.home.opencodeV2.enable = lib.mkEnableOption "OpenCode v2";

  config = lib.mkIf cfg.enable {
    # OpenCode v2's supported installer is Bun. Keep the application in
    # Bun's writable user prefix so its self-updater can work.
    home = {
      packages = [
        pkgs.bun
        browser-control-extension-path
      ];
      sessionPath = lib.mkAfter [ "$HOME/.bun/bin" ];
      shellAliases = {
        oc = "opencode";
      };
    };

    # Nushell does not consume Home Manager's POSIX session-variable script.
    # Set its structured PATH directly so `nu` also works when it is launched
    # without an intermediate Bash or Zsh login shell.
    programs.nushell.extraEnv = lib.mkAfter ''
      let bun_bin_dir = ($nu.home-dir | path join ".bun" "bin")
      $env.PATH = (
        $env.PATH
        | prepend $bun_bin_dir
        | uniq
      )
    '';

    # Reviewer plugin ships as repo-local .opencode/plugins (auto-loaded,
    # proven mechanism). The HM-managed absolute-path plugin dir NEVER
    # loaded (zero loader lines across restarts; absolute-path global
    # plugins appear unsupported in v2), so that vehicle is out.
    # Single source: .opencode/plugins/muse-auto-review/index.ts.

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = true;
      # Global default model. No variant here: the muse routing subagent
      # below pins xhigh explicitly. Astra stays manually selectable and is
      # never the global default.
      model = "opencode-go/muse-spark-1.3-contributor";
      # Ask by default is SUSPENDED 2026-09-08: ctx.session.generate runs
      # the review with FULL session context on the session model, so every
      # risky action costs ~2x model and caused rate-limit errors. Do not
      # re-enable default-ask until the reviewer is an isolated cheap call
      # (fix generate-text routing or use a small model) and in-hook notes
      # are proven to land. Permissive shell restored meanwhile.
      # Subagent launches: routine targets (muse, explore, general) run
      # free; everything else (incl. Astra) asks and the reviewer judges
      # it from chat. No per-agent hardcode on the restricted side — the
      # trailing * is the gate. (Each gated launch costs one review call.)
      permissions = [
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "rm -rf *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "sudo rm -rf *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "git push *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "echo *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "printf *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "pwd";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "ls *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "whoami";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "hostname";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "date *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "uname *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "true";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "basename *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "dirname *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "head *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "tail *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "wc *";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "muse";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "explore";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "general";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "*";
          effect = "ask";
        }
      ];
      # Model-routing subagents only. Build and Plan are intentionally left
      # untouched so upstream improvements keep applying. All entries are
      # mode = "subagent", so they never appear as primary agents.
      # No subagent_depth is set: OpenCode's default one-hop behavior stays.
      agents = {
        muse = {
          mode = "subagent";
          model = "opencode-go/muse-spark-1.3-contributor#xhigh";
          description = ''
            Muse Spark 1.3 Contributor at XHIGH reasoning.

            Always use this target when delegating work to Muse.

            It is appropriate for implementation, research, exploration, review,
            parallelizable work, and cheaper supporting work when the primary model
            is GPT-6 Astra.
          '';
        };
        astra = {
          mode = "subagent";
          model = "openai/gpt-6-astra#low";
          steps = 30;
          description = ''
            GPT-6 Astra at LOW reasoning.

            This is the default Astra target. Use it whenever Astra is requested
            without a reasoning level.

            If the user explicitly requests medium or high reasoning, use the
            matching astra-medium or astra-high subagent instead. There are no
            higher-level Astra subagents: for xhigh or max, the user runs Astra
            directly as the primary model.

            Complete the assigned task and return a useful report/result to the
            parent agent. If approaching the step limit, prioritize reporting
            findings, completed work, unresolved issues, and recommended next actions.
          '';
        };
        astra-medium = {
          mode = "subagent";
          model = "openai/gpt-6-astra#medium";
          steps = 30;
          description = ''
            GPT-6 Astra at MEDIUM reasoning.
            Use when the user explicitly requests Astra medium.
            Complete the assigned task and return the result to the parent.
          '';
        };
        astra-high = {
          mode = "subagent";
          model = "openai/gpt-6-astra#high";
          steps = 30;
          description = ''
            GPT-6 Astra at HIGH reasoning.
            Use when the user explicitly requests Astra high.
            Complete the assigned task and return the result to the parent.
          '';
        };
      };
    };

    # Bootstrap a fresh machine, then let OpenCode maintain its own
    # binary. Normal Home Manager activations do not reinstall it.
    # Migrates the beta layout: stable package is @opencode/cli (binary
    # `opencode`, with an `opencode2` compat shim), replacing
    # @opencode-ai/cli@beta (`opencode2` only).
    home.activation.installOpenCodeV2 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.bun/bin/opencode" ]; then
        run ${lib.getExe pkgs.bun} install -g --trust @opencode/cli
      fi
      if [ -d "$HOME/.bun/install/global/node_modules/@opencode-ai/cli" ]; then
        run ${lib.getExe pkgs.bun} remove -g @opencode-ai/cli || true
      fi
    '';

    # Browser Control drives the existing Chromium-family browser (Helium
    # here) through a local relay + extension. OpenCode runs it via shell,
    # so no opencode.json MCP entry is needed (skill-only, per upstream).
    # Same bun-global pattern as OpenCode: bootstrap once, update explicitly
    # with `bun install -g --trust @opencode-ai/browser-control`.
    home.activation.installBrowserControl = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.bun/bin/browser-control" ]; then
        run ${lib.getExe pkgs.bun} install -g --trust @opencode-ai/browser-control
      fi
    '';

    # Sync the skill text from the installed CLI so skill and driver never
    # drift. Writes the canonical global location OpenCode reads natively
    # (~/.config/opencode/skills/...), then removes the one-off
    # `npx skills add -a opencode` copy in ~/.agents/skills so there is a
    # single source. Safe to re-run; OpenCode picks the managed copy up on
    # next start. If the CLI is missing, leave any existing skill alone.
    # NOTE: cli.js has a `#!/usr/bin/env node` shebang, but activation runs
    # with a minimal PATH, so put Nix's node first explicitly.
    home.activation.syncBrowserControlSkill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.nodejs}/bin:$PATH"
      if [ -x "$HOME/.bun/bin/browser-control" ]; then
        mkdir -p "$HOME/.config/opencode/skills/browser-control"
        "$HOME/.bun/bin/browser-control" skill > "$HOME/.config/opencode/skills/browser-control/SKILL.md"
        if [ -d "$HOME/.agents/skills/browser-control" ]; then
          rm -rf "$HOME/.agents/skills/browser-control"
        fi
      fi
    '';
  };
}
