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
    optionalAttrs
    types
    ;
  cfg = config.modules.home.opencodeCore;
  opencode-plugins = builtins.fromJSON (builtins.readFile ./opencode-plugins.json);
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
      description = "Default OpenCode model written to config.json.";
    };

    provider = mkOption {
      type = types.attrs;
      default = { };
      description = "Provider configuration written to config.json.";
    };

    ohMyOpenCode = mkOption {
      type = types.attrs;
      default = {
        auto_update = false;
        auto_commit = false;
        model_fallback = true;
        runtime_fallback = true;
        disabledHooks = [ "auto-update-checker" ];
        disabled_mcps = [ ];
        disabled_skills = [ "playwright" ];

        agents = {
          Sisyphus = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "github-copilot/claude-opus-4.6"
              "opencode-go/minimax-m2.7"
            ];
            ultrawork = {
              model = "github-copilot/claude-opus-4.6";
              variant = "thinking";
            };
          };
          prometheus = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "opencode-go/minimax-m2.7"
            ];
          };
          metis = {
            model = "github-copilot/claude-opus-4.6";
            variant = "max";
            fallback_models = [
              "opencode-go/minimax-m2.7"
            ];
          };
          atlas = {
            model = "opencode-go/minimax-m2.7";
          };
          oracle = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "github-copilot/gemini-3.1-pro-preview"
              "opencode-go/minimax-m2.7"
            ];
          };
          momus = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "github-copilot/gemini-3.1-pro-preview"
              "opencode-go/minimax-m2.7"
            ];
          };
          hephaestus = {
            model = "openai/gpt-5.3-codex";
            variant = "high";
            fallback_models = [
              "opencode-go/minimax-m2.7"
            ];
          };
          frontend-ui-ux-engineer = {
            model = "github-copilot/claude-opus-4.6";
            fallback_models = [
              "opencode-go/minimax-m2.7"
            ];
          };
          multimodal-looker = {
            model = "openai/gpt-5.4";
            variant = "medium";
          };
          document-writer = {
            model = "opencode-go/minimax-m2.7";
          };
          explore = {
            model = "opencode-go/minimax-m2.7";
          };
          librarian = {
            model = "opencode-go/minimax-m2.7";
          };
        };

        categories = {
          quick = {
            model = "opencode-go/minimax-m2.7";
          };
          visual-engineering = {
            model = "github-copilot/gemini-3.1-pro-preview";
            fallback_models = [
              "github-copilot/claude-opus-4.6"
              "opencode-go/minimax-m2.7"
            ];
          };
          artistry = {
            model = "github-copilot/gemini-3.1-pro-preview";
            fallback_models = [
              "github-copilot/claude-opus-4.6"
              "opencode-go/minimax-m2.7"
            ];
          };
          writing = {
            model = "github-copilot/gemini-3-flash-preview";
            fallback_models = [
              "opencode-go/minimax-m2.7"
            ];
          };
          unspecified-low = {
            model = "opencode-go/minimax-m2.7";
          };
          unspecified-high = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "github-copilot/claude-opus-4.6"
              "opencode-go/minimax-m2.7"
            ];
          };
          ultrabrain = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "github-copilot/gemini-3.1-pro-preview"
              "github-copilot/claude-opus-4.6"
            ];
          };
          deep = {
            model = "openai/gpt-5.3-codex";
            variant = "high";
            fallback_models = [
              "github-copilot/claude-opus-4.6"
              "opencode-go/minimax-m2.7"
            ];
          };
        };

        background_task = {
          providerConcurrency = {
            github-copilot = 3;
            openai = 3;
            opencode = 10;
            "opencode-go" = 10;
          };
          modelConcurrency = {
            "github-copilot/claude-opus-4.6" = 2;
            "openai/gpt-5.4" = 2;
          };
        };
      };
      description = "Settings written to oh-my-opencode.json.";
    };

    autoupdate = mkOption {
      type = types.bool;
      default = false;
      description = "Whether programs.opencode autoupdate is enabled.";
    };

    smallModel = mkOption {
      type = types.str;
      default = "opencode-go/minimax-m2.7";
      description = "Model used for programs.opencode.settings.small_model.";
    };

    pluginPins = mkOption {
      type = types.attrsOf types.str;
      default = opencode-plugins;
      description = "Plugin version pins keyed by plugin name.";
    };

    pinnedPlugins = mkOption {
      type = types.listOf types.str;
      default = [
        "oh-my-opencode"
        "opencode-quotas"
      ];
      description = "Plugins resolved from pluginPins and rendered as name@version.";
    };

    extraPlugins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional literal plugin entries appended to programs.opencode.settings.plugin.";
    };
  };

  config = mkIf cfg.enable {
    home.file.".config/opencode/config.json".text = builtins.toJSON (
      {
        model = cfg.model;
      }
      // optionalAttrs (cfg.provider != { }) {
        provider = cfg.provider;
      }
    );

    home.file.".config/opencode/oh-my-opencode.json".text = builtins.toJSON cfg.ohMyOpenCode;

    programs.opencode = {
      enable = true;
      package = cfg.package;
      settings = {
        autoupdate = cfg.autoupdate;
        small_model = cfg.smallModel;
        plugin = (map (name: "${name}@${cfg.pluginPins.${name}}") cfg.pinnedPlugins) ++ cfg.extraPlugins;
      };
    };
  };
}
