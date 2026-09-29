# OpenCode and Browser Control are Bun globals so their self-updaters work.
# The repo-local reviewer plugin lives in .opencode/plugins (absolute-path
# global plugins do not load in v2).
{ lib, pkgs, ... }:
let
  bun = lib.getExe pkgs.bun;
  browserControl = "$HOME/.bun/bin/browser-control";

  # Upstream documents `npm root --global`, which misses the Bun layout.
  browser-control-extension-path = pkgs.writeShellApplication {
    name = "browser-control-extension-path";
    text = ''
      ext="$HOME/.bun/install/global/node_modules/@opencode-ai/browser-control/extension/dist"
      printf '%s\n' "$ext"
      if [ ! -f "$ext/manifest.json" ]; then
        echo "extension not found (run: bun install -g --trust @opencode-ai/browser-control)" >&2
        exit 1
      fi
    '';
  };

  rules =
    action: effect:
    map (resource: {
      inherit action resource effect;
    });

  astra = level: extra: {
    mode = "subagent";
    model = "openai/gpt-6-astra#${lib.toLower level}";
    steps = 30;
    description = ''
      GPT-6 Astra at ${level} reasoning.
      ${extra}
      Complete the assigned task and return the result to the parent. Near the
      step limit, prioritize reporting findings, completed work, and open issues.
    '';
  };
in
{
  home.packages = [
    pkgs.bun
    browser-control-extension-path
  ];
  home.shellAliases.oc = "opencode";

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = true;
    model = "opencode-go/muse-spark-1.3-contributor";
    # Ask-by-default is suspended: the reviewer plugin runs on the full
    # session model, doubling cost and hitting rate limits. Subagent launches
    # other than the routine targets still ask.
    permissions =
      rules "shell" "allow" [ "*" ]
      ++ rules "shell" "ask" [
        "rm -rf *"
        "sudo rm -rf *"
        "git push *"
        "jj git push *"
      ]
      ++ rules "subagent" "allow" [
        "muse"
        "explore"
        "general"
      ]
      ++ rules "subagent" "ask" [ "*" ];
    # Model-routing subagents only; Build and Plan keep upstream defaults.
    agents = {
      muse = {
        mode = "subagent";
        model = "opencode-go/muse-spark-1.3-contributor#xhigh";
        description = ''
          Muse Spark 1.3 Contributor at XHIGH reasoning.
          Always use this target when delegating work to Muse. It suits
          implementation, research, exploration, review, parallelizable work,
          and cheaper supporting work when the primary model is GPT-6 Astra.
        '';
      };
      astra = astra "LOW" ''
        The default Astra target: use it whenever Astra is requested without a
        reasoning level. For medium or high, use astra-medium or astra-high; for
        xhigh or max, the user runs Astra directly as the primary model.
      '';
      astra-medium = astra "MEDIUM" "Use when the user explicitly requests Astra medium.";
      astra-high = astra "HIGH" "Use when the user explicitly requests Astra high.";
    };
  };

  # Bootstrap once; the tools update themselves afterwards.
  home.activation.installOpenCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.bun/bin/opencode" ]; then
      run ${bun} install -g --trust @opencode/cli
    fi
    if [ ! -x "${browserControl}" ]; then
      run ${bun} install -g --trust @opencode-ai/browser-control
    fi
  '';

  # Keep the Browser Control skill in sync with the installed CLI. Its
  # `#!/usr/bin/env node` shebang needs node on activation's minimal PATH.
  home.activation.syncBrowserControlSkill = lib.hm.dag.entryAfter [ "installOpenCode" ] ''
    if [ -x "${browserControl}" ]; then
      skill="$HOME/.config/opencode/skills/browser-control"
      run mkdir -p "$skill"
      PATH="${pkgs.nodejs}/bin:$PATH" "${browserControl}" skill > "$skill/SKILL.md"
    fi
  '';
}
