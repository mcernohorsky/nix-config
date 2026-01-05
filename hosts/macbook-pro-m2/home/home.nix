{ pkgs, inputs, ... }:
let
  opencode-plugins = builtins.fromJSON (builtins.readFile ./opencode-plugins.json);
in
{
  # disabledModules = [ "programs/ghostty.nix" ];
  imports = [ ];

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
      ".config/opencode/oh-my-opencode.json".text = builtins.toJSON {
        google_auth = false;
        auto_update = false; # Disable plugin self-update (use bun update in ~/.cache/opencode/)
        disabledHooks = [ "auto-update-checker" ]; # Prevents EROFS errors from config writes
        disabled_mcps = [ "websearch_exa" ];
        disabled_skills = [ "playwright" ];
        agents = {
          Sisyphus = {
            model = "google/claude-opus-4-5-thinking-high";
          };
          frontend-ui-ux-engineer = {
            model = "google/gemini-3-pro-high";
          };
          document-writer = {
            model = "google/gemini-3-flash";
          };
          multimodal-looker = {
            model = "google/gemini-3-flash";
          };
          oracle = {
            model = "github-copilot/gpt-5.2";
          };
          explore = {
            model = "google/gemini-3-flash";
          };
          librarian = {
            model = "google/gemini-3-flash";
          };
          Planner-Sisyphus = {
            model = "github-copilot/gpt-5.2";
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
      nixfmt-rfc-style

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
      playwright-mcp # For opencode MCP integration (includes bundled browsers)
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
        # theme = "light:GruvboxLight,dark:catppuccin-mocha";
        theme = "light:Gruvbox Light,dark:Gruvbox Dark Hard";
        background-opacity = 0.95;
        background-blur = 10;
        macos-option-as-alt = "left";
        mouse-hide-while-typing = true;
        command = "${pkgs.bashInteractive}/bin/bash -i -l -c 'exec nu'";
        # keybind = "global:opt+ =toggle_quick_terminal";
        quick-terminal-animation-duration = 0;
        macos-non-native-fullscreen = true;
        # macos-icon = "retro";
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
    };

    ripgrep = {
      enable = true;
    };

    # AI coding assistant - binary from llm-agents.nix, plugins auto-install to ~/.cache/opencode/
    # Update binary: nix flake update llm-agents && darwin-rebuild switch
    # Update plugins: cd ~/.cache/opencode && bun update
    opencode = {
      enable = true;
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      settings = {
        autoupdate = false; # Prevent binary self-update (managed by nix flake update)
        small_model = "opencode/grok-code";
        plugin = [
          "oh-my-opencode@${opencode-plugins.oh-my-opencode}"
          "opencode-antigravity-auth@${opencode-plugins.opencode-antigravity-auth}"
        ];
        mcp = {
          playwright = {
            type = "local";
            command = [
              "${pkgs.lib.getExe pkgs.playwright-mcp}" # Nix-managed with bundled browsers
              "--browser"
              "chromium"
            ];
            enabled = false;
          };
        };
        provider = {
          google = {
            models = {
              "gemini-3-pro-high" = {
                name = "Gemini 3 Pro High (Antigravity)";
                limit = {
                  context = 1048576;
                  output = 65535;
                };
                modalities = {
                  input = [
                    "text"
                    "image"
                    "pdf"
                  ];
                  output = [ "text" ];
                };
              };
              "gemini-3-flash" = {
                name = "Gemini 3 Flash (Antigravity)";
                limit = {
                  context = 1048576;
                  output = 65536;
                };
                modalities = {
                  input = [
                    "text"
                    "image"
                    "pdf"
                  ];
                  output = [ "text" ];
                };
              };
              "claude-opus-4-5-thinking-high" = {
                name = "Claude Opus 4.5 Thinking High (Antigravity)";
                limit = {
                  context = 200000;
                  output = 64000;
                };
                modalities = {
                  input = [
                    "text"
                    "image"
                    "pdf"
                  ];
                  output = [ "text" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
