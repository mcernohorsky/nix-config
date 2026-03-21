{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    recursiveUpdate
    types
    ;
  cfg = config.modules.home.opencodeCore;
  opencode-plugins = builtins.fromJSON (builtins.readFile ./opencode-plugins.json);

  defaultAgents = {
    build = {
      mode = "primary";
      model = "cursor/composer-2";
      tools = {
        "context7_*" = true;
        "exa_*" = true;
      };
    };
    plan = {
      mode = "primary";
      model = "openai/gpt-5.4";
      reasoningEffort = "high";
    };
    explore = {
      mode = "subagent";
      model = "opencode-go/minimax-m2.7";
      tools = {
        "context7_*" = true;
        "exa_*" = true;
      };
    };
    general = {
      mode = "subagent";
      model = "opencode-go/minimax-m2.7";
    };
  };
in
{
  options.modules.home.opencodeCore = {
    enable = mkEnableOption "shared OpenCode Home Manager configuration";

    package = mkOption {
      type = types.package;
      default = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      description = "OpenCode package to install via Home Manager.";
    };

    model = mkOption {
      type = types.str;
      default = "fireworks-ai/accounts/fireworks/models/kimi-k2p5";
      description = "Default OpenCode model written to opencode.json.";
    };

    provider = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Extra provider entries merged into opencode.json, on top of the
        {literal}`cursor` stub required by
        [opencode-cursor-oauth](https://github.com/ephraimduncan/opencode-cursor).
      '';
    };

    autoupdate = mkOption {
      type = types.bool;
      default = false;
      description = "Whether programs.opencode autoupdate is enabled.";
    };

    permission = mkOption {
      type = types.oneOf [
        types.str
        types.attrs
      ];
      default = {
        "*" = "allow";
        bash = {
          "*" = "allow";
          "rm -rf /" = "ask";
          "rm -rf /*" = "ask";
          "mkfs*" = "ask";
          "dd * of=/dev/*" = "ask";
          "diskutil erase*" = "ask";
          "git reset --hard*" = "ask";
          "git clean -fd*" = "ask";
          "git push --force*" = "ask";
        };
      };
      description = ''
        OpenCode permission policy written to
        {literal}`programs.opencode.settings.permission`.
        Defaults to allow-by-default with explicit prompts for
        especially destructive bash commands.
      '';
    };

    smallModel = mkOption {
      type = types.str;
      default = "opencode-go/minimax-m2.7";
      description = "Model used for programs.opencode.settings.small_model.";
    };

    pluginPins = mkOption {
      type = types.attrsOf types.str;
      default = opencode-plugins;
      description = "Plugin version pins keyed by npm package name.";
    };

    pinnedPlugins = mkOption {
      type = types.listOf types.str;
      default = [
        "opencode-cursor-oauth"
      ];
      description = "Plugins resolved from pluginPins and rendered as name@version.";
    };

    extraPlugins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional literal plugin entries appended to programs.opencode.settings.plugin.";
    };

    agents = mkOption {
      type = types.attrs;
      default = defaultAgents;
      description = ''
        Per-agent overrides written to {literal}`programs.opencode.settings.agent`
        (build, plan, explore, general). Replace the default attrset in your home
        config to customize; there is no deep merge.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Prefer Bun for JS tooling; OpenCode’s own runtime is Bun-based.
    home.packages = [ pkgs.bun ];

    programs.opencode = {
      enable = true;
      package = cfg.package;
      settings = {
        autoupdate = cfg.autoupdate;
        small_model = cfg.smallModel;
        model = cfg.model;
        provider = recursiveUpdate {
          cursor = {
            name = "Cursor";
          };
        } cfg.provider;
        plugin = (map (name: "${name}@${cfg.pluginPins.${name}}") cfg.pinnedPlugins) ++ cfg.extraPlugins;
        mcp = {
          context7 = {
            type = "remote";
            url = "https://mcp.context7.com/mcp";
            enabled = true;
          };
          exa = {
            type = "remote";
            url = "https://mcp.exa.ai/mcp";
            enabled = true;
          };
        };
        permission = cfg.permission;
        tools = {
          "context7_*" = false;
          "exa_*" = false;
        };
        agent = cfg.agents;
      };
    };
  };
}
