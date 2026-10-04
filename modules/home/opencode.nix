# OpenCode and Browser Control are Bun globals so their self-updaters work.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  bun = lib.getExe pkgs.bun;
  browserControl = "$HOME/.bun/bin/browser-control";
  bunConfig = ''
    [install]
    globalDir = "${config.home.homeDirectory}/.bun/install/global"
    globalBinDir = "${config.home.homeDirectory}/.bun/bin"
  '';

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

  # The shell scanner checks each command in a compound expression, but keeps
  # wrappers and executable paths. Cover sudo/env prefixes and /bin/rm too.
  shellRules =
    effect: commands:
    rules "shell" effect (
      lib.concatMap (command: [
        command
        "* ${command}"
        "*/${command}"
      ]) commands
    );

in
{
  home.packages = [
    pkgs.bun
    browser-control-extension-path
  ];
  home.shellAliases.oc = "opencode";

  # XDG_CACHE_HOME changes Bun's default global install location. Pin both
  # paths so T3's updater modifies the same binaries that its PATH resolves.
  # Bun checks the XDG file instead of the home file when XDG_CONFIG_HOME
  # is set; T3's Mac launchd environment does not set it.
  home.file.".bunfig.toml".text = bunConfig;
  xdg.configFile.".bunfig.toml".text = bunConfig;

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = true;
    model = "opencode/muse-spark-1.3-contributor-free";
    # V2 already allows routine tools and subagents. Keep its agent-specific
    # restrictions and .env prompts, while allowing access outside the project.
    # These command patterns are guardrails, not a shell sandbox. Avoid --auto:
    # it bypasses ask rules (deny rules remain enforced).
    permissions =
      rules "external_directory" "allow" [ "*" ]
      ++ shellRules "ask" [
        "rm *-*r*"
        "rm *-*R*"
        "rm *--recursive*"
        "git *reset *--hard*"
        "git *clean *-*f*"
        "git *clean *--force*"
        "git *push *--force*"
        "git *push *-f*"
        "git *push *+*"
        "jj *git push *--allow-backwards*"
        "terraform *destroy *"
        "tofu *destroy *"
        "terraform *apply *-destroy*"
        "tofu *apply *-destroy*"
        "restic *forget *"
      ]
      ++ shellRules "deny" [
        "mkfs* *"
        "wipefs *"
        "shred *"
        "dd *of=/dev/*"
        "diskutil erase* *"
        "diskutil partitionDisk *"
        "sgdisk *--zap*"
      ];
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
