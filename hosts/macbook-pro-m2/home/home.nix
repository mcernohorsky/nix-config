{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  opencode-plugins = builtins.fromJSON (builtins.readFile ./opencode-plugins.json);
in
{
  imports = [
    ../modules/portal.nix
  ];

  # Portal - Mobile-first web UI for OpenCode
  # Access from iPhone: https://macbook-pro-m2.tailc41cf5.ts.net
  # Uses port 4097 to avoid conflicts with manual `opencode` sessions (which use 4096)
  services.portal = {
    enable = true;
    workingDirectory = "/Users/matt/Developer";
    opencodePort = 4097; # Dedicated port for Portal (avoids conflict with terminal sessions)
  };

  # User Configuration
  home = {
    username = "matt";
    homeDirectory = "/Users/matt";
    stateVersion = "23.11";

    # Add scripts to the PATH.
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.bun/bin" # For bun/bunx
    ];
    sessionVariables = {
      DIRENV_WARN_TIMEOUT = "0";
      # NODE_PATH not needed - opencode manages plugins in ~/.cache/opencode/
    };

    file = {
      ".hushlogin".text = ""; # Disable login messages in the terminal.
      "Developer/.keep".text = ""; # The Developer directory has a cool icon on macOS.
      ".local/bin/dev" = {
        source = ./bin/dev;
        executable = true;
      };
      # Make the helix background transparent.
      ".config/helix/themes/custom.toml".text = ''
        inherits = "gruvbox_dark_hard"
        # inherits = "catppuccin_mocha"
        "ui.background" = {}
      '';
      ".config/zellij/config.kdl".source = ./config.kdl;

      # Oh My OpenCode Configuration
      # Agents guide: https://github.com/code-yeongyu/oh-my-opencode/blob/dev/docs/guide/agent-model-matching.md
      # OpenAI handles most high-value GPT work, OpenCode Go handles cheap utility work,
      # and GitHub Copilot provides selected Claude/Gemini fallbacks where they are strongest.
      ".config/opencode/oh-my-opencode.json".text = builtins.toJSON {
        auto_update = false; # Disable plugin self-update (use bun update in ~/.cache/opencode/)
        auto_commit = false; # Agents only commit when explicitly asked (v3.11 default)
        hashline_edit = true; # Hash-anchored edits for safer file modifications (v3.10)
        runtime_fallback = true;
        disabledHooks = [ "auto-update-checker" ]; # Prevents EROFS errors from config writes
        disabled_mcps = [ ]; # websearch_exa re-enabled for research capabilities
        disabled_skills = [ "playwright" ];

        # Agent model assignments — tuned from OMO defaults plus local subscription constraints.
        agents = {
          # Orchestrators and planners
          Sisyphus = {
            model = "openai/gpt-5.4";
            variant = "medium";
            fallback_models = [
              "github-copilot/claude-sonnet-4.6"
              "opencode-go/kimi-k2.5"
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
              "opencode-go/glm-5"
              "github-copilot/claude-sonnet-4.6"
            ];
          };
          metis = {
            model = "github-copilot/claude-opus-4.6";
            variant = "max";
            fallback_models = [
              "opencode-go/glm-5"
              "openai/gpt-5.4"
            ];
          };
          atlas = {
            model = "github-copilot/claude-sonnet-4.6";
            fallback_models = [
              "opencode-go/kimi-k2.5"
              "openai/gpt-5.4"
            ];
          };

          # Specialists — GPT via OpenAI
          oracle = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "github-copilot/gemini-3.1-pro-preview"
              "opencode-go/glm-5"
            ];
          };
          momus = {
            model = "openai/gpt-5.4";
            variant = "xhigh";
            fallback_models = [
              "github-copilot/gemini-3.1-pro-preview"
              "opencode-go/glm-5"
            ];
          };
          # Hephaestus — autonomous deep worker, Codex remains the default lane
          hephaestus = {
            model = "openai/gpt-5.3-codex";
            variant = "medium";
            fallback_models = [
              "opencode-go/glm-5"
              "github-copilot/claude-sonnet-4.6"
            ];
          };

          # Visual/creative — Copilot Gemini/Claude where they remain strongest.
          frontend-ui-ux-engineer = {
            model = "github-copilot/claude-sonnet-4.6";
            fallback_models = [
              "opencode-go/kimi-k2.5"
              "openai/gpt-5.4"
            ];
          };

          document-writer = {
            model = "opencode-go/minimax-m2.5";
            fallback_models = [
              "opencode/minimax-m2.5-free"
              "opencode/nemotron-3-super-free"
              "github-copilot/gemini-3-flash-preview"
            ];
          };

          # Utility runners — MiniMax for cheap speed, Kimi for multimodal support
          explore = {
            model = "opencode-go/minimax-m2.5";
            fallback_models = [
              "opencode/minimax-m2.5-free"
              "opencode/nemotron-3-super-free"
              "github-copilot/gemini-3-flash-preview"
            ];
          };
          librarian = {
            model = "opencode-go/minimax-m2.5";
            fallback_models = [
              "opencode/minimax-m2.5-free"
              "opencode/nemotron-3-super-free"
              "github-copilot/gemini-3-flash-preview"
            ];
          };
          multimodal-looker = {
            model = "openai/gpt-5.4";
            variant = "medium";
            fallback_models = [ "opencode-go/kimi-k2.5" ];
          };
        };

        # Category model defaults — used when agents delegate tasks
        categories = {
          quick = {
            model = "opencode-go/minimax-m2.5";
            fallback_models = [
              "opencode/minimax-m2.5-free"
              "opencode/nemotron-3-super-free"
            ];
          };
          visual-engineering = {
            model = "github-copilot/gemini-3.1-pro-preview";
            fallback_models = [
              "openai/gpt-5.4"
              "opencode-go/glm-5"
            ];
          };
          artistry = {
            model = "github-copilot/gemini-3.1-pro-preview";
            fallback_models = [ "openai/gpt-5.4" ];
          };
          writing = {
            model = "github-copilot/gemini-3-flash-preview";
            fallback_models = [
              "opencode-go/glm-5"
              "openai/gpt-5.4"
            ];
          };
          unspecified-low = {
            model = "openai/gpt-5.4";
            variant = "low";
            fallback_models = [
              "opencode-go/kimi-k2.5"
              "github-copilot/gemini-3-flash-preview"
              "opencode/minimax-m2.5-free"
            ];
          };
          unspecified-high = {
            model = "openai/gpt-5.4";
            variant = "high";
            fallback_models = [
              "opencode-go/glm-5"
              "github-copilot/claude-sonnet-4.6"
            ];
          };
          ultrabrain = {
            model = "openai/gpt-5.4";
            variant = "xhigh";
            fallback_models = [
              "github-copilot/gemini-3.1-pro-preview"
              "github-copilot/claude-opus-4.6"
            ];
          };
          deep = {
            model = "openai/gpt-5.3-codex";
            variant = "medium";
            fallback_models = [
              "opencode-go/glm-5"
              "github-copilot/claude-sonnet-4.6"
            ];
          };
        };

        # Concurrency limits — prevent runaway parallel requests
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
    };

    packages = with pkgs; [
      lazydocker
      tree
      fd
      bottom
      hyperfine
      gh

      tailscale
      bitwarden-desktop

      nixd
      nixfmt

      bun # for bunx and general bun usage
      nodejs # needed for running globally installed npm packages (they use #!/usr/bin/env node)

      # fonts
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      inter
      merriweather
      roboto

      # AI Tools
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.amp
    ];

    shellAliases = {
      lg = "lazygit";
      ld = "lazydocker";
      zj = "zellij";
      oc = "opencode";
    };
  };

  programs.home-manager.enable = true;

  programs = {
    helix = {
      enable = true;
      package = inputs.helix-master.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultEditor = true;
      settings = {
        theme = "custom";
        editor = {
          scrolloff = 10;
          shell = [
            "nu"
            "-c"
          ];
          line-number = "relative";
          cursorline = true;
          true-color = true;
          rulers = [ 100 ];
          bufferline = "multiple";
          color-modes = true;
          text-width = 100;
          popup-border = "all";
          jump-label-alphabet = "jkl;fdsauiohnmretcgwvpyqxbz";
          statusline = {
            left = [
              "mode"
              "spinner"
              "version-control"
              "file-name"
              "read-only-indicator"
              "file-modification-indicator"
            ];
            right = [
              "diagnostics"
              "selections"
              "register"
              "position"
              "position-percentage"
              "total-line-numbers"
              "file-encoding"
            ];
          };
          lsp = {
            display-messages = true;
          };
          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };
          indent-guides = {
            render = true;
            character = "┊";
          };
          soft-wrap.enable = true;
        };
        keys = {
          normal = {
            "x" = "select_line_below";
            "X" = "select_line_above";
            "A-x" = "extend_to_line_bounds";
            "D" = [
              "ensure_selections_forward"
              "extend_to_line_end"
              "delete_selection"
            ];
            "C-j" = [
              "extend_to_line_bounds"
              "delete_selection"
              "move_line_down"
              "paste_before"
            ];
            "C-k" = [
              "extend_to_line_bounds"
              "delete_selection"
              "move_line_up"
              "paste_before"
            ];
            space = {
              l = ":toggle lsp.display-inlay-hints";
              x = ":toggle whitespace.render all none";
              "." = "file_picker_in_current_buffer_directory";
            };
          };
          select = {
            "x" = "select_line_below";
            "X" = "select_line_above";
            "A-x" = "extend_to_line_bounds";
            "D" = [
              "ensure_selections_forward"
              "extend_to_line_end"
              "delete_selection"
            ];
            space = {
              l = ":toggle lsp.display-inlay-hints";
              x = ":toggle whitespace.render all none";
              "." = "file_picker_in_current_buffer_directory";
            };
          };
        };
      };
      languages = {
        language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "nixfmt";
            language-servers = [ "nixd" ];
          }
        ];
        language-server = {
          nixd.command = "nixd";
        };
      };
    };

    git = {
      enable = true;
      settings = {
        user.name = "Matt Cernohorsky";
        user.email = "matt@cernohorsky.ca";
        github.user = "mcernohorsky";
        init.defaultBranch = "main";
      };
    };

    zsh.enable = true;
    bash.enable = true;
    nushell = {
      enable = true;
      settings = {
        show_banner = false;
      };
    };

    ghostty = {
      enable = true;
      package = null;
      settings = {
        auto-update = "off";
        theme = "light:Gruvbox Light,dark:Gruvbox Dark Hard";
        background-opacity = 0.95;
        background-blur = 10;
        macos-option-as-alt = "left";
        mouse-hide-while-typing = true;
        command = "${pkgs.bashInteractive}/bin/bash -i -l -c 'exec nu'";
        quick-terminal-animation-duration = 0;
        macos-non-native-fullscreen = true;
      };
    };

    # CLI Tools
    starship = {
      enable = true;
    };

    atuin = {
      enable = true;
    };

    nix-index = {
      enable = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      config = {
        warn_timeout = 0;
      };
    };

    fzf = {
      enable = true;
    };

    zellij = {
      enable = true;
    };

    zoxide = {
      enable = true;
    };

    bat = {
      enable = true;
    };

    jujutsu = {
      enable = true;
    };

    lazygit = {
      enable = true;
    };

    yazi = {
      enable = true;
      shellWrapperName = "y";
    };

    ripgrep = {
      enable = true;
    };

    # AI coding assistant - binary from llm-agents.nix, plugins auto-install to ~/.cache/opencode/
    # Update binary: nix flake update llm-agents && darwin-rebuild switch
    # Update plugins: just update-plugins && darwin-rebuild switch
    # Auth tokens: ~/.local/share/opencode/auth.json (run `opencode auth login`)
    opencode = {
      enable = true;
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      settings = {
        autoupdate = false; # Prevent binary self-update (managed by nix flake update)
        small_model = "opencode-go/minimax-m2.5";
        plugin = [
          "oh-my-opencode@${opencode-plugins.oh-my-opencode}"
          "opencode-quotas@${opencode-plugins.opencode-quotas}"
        ];
      };
    };
  };
}
