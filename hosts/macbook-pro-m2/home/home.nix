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
  # disabledModules = [ "programs/ghostty.nix" ];
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
      # Thinking variants: max for orchestrators, high for specialists, low for utility runners
      ".config/opencode/oh-my-opencode.json".text = builtins.toJSON {
        google_auth = false;
        auto_update = false; # Disable plugin self-update (use bun update in ~/.cache/opencode/)
        auto_commit = false; # Agents only commit when explicitly asked (v3.11 default)
        hashline_edit = true; # Hash-anchored edits for safer file modifications (v3.10)
        disabledHooks = [ "auto-update-checker" ]; # Prevents EROFS errors from config writes
        disabled_mcps = [ ]; # websearch_exa re-enabled for research capabilities
        disabled_skills = [ "playwright" ];

        # Agent model assignments — Claude/Gemini via Antigravity, GPT via GitHub Copilot
        agents = {
          # Orchestrators — max thinking for planning accuracy
          Sisyphus = {
            model = "google/antigravity-claude-opus-4-6-thinking";
            variant = "max";
            ultrawork = {
              model = "google/antigravity-claude-opus-4-6-thinking";
              variant = "max";
            };
          };
          prometheus = {
            model = "google/antigravity-claude-opus-4-6-thinking";
            variant = "max";
          };
          metis = {
            model = "google/antigravity-claude-opus-4-6-thinking";
            variant = "max";
          };
          atlas = {
            model = "google/antigravity-claude-sonnet-4-6";
          };

          # Specialists — GPT via Copilot
          oracle = {
            model = "github-copilot/gpt-5.4";
          };
          momus = {
            model = "github-copilot/gpt-5.4";
          };
          # Hephaestus — autonomous deep worker, GPT-5.3 Codex is the OMO-recommended model
          hephaestus = {
            model = "github-copilot/gpt-5.3-codex";
          };

          # Visual/creative — Gemini 3.1 Pro with high thinking
          frontend-ui-ux-engineer = {
            model = "google/antigravity-gemini-3.1-pro";
            variant = "high";
          };

          # Utility runners — speed over intelligence, no thinking variants
          explore = {
            model = "google/antigravity-gemini-3-flash";
          };
          librarian = {
            model = "google/antigravity-gemini-3-flash";
          };
          document-writer = {
            model = "google/antigravity-gemini-3-flash";
          };
          multimodal-looker = {
            model = "google/antigravity-gemini-3-flash";
          };
        };

        # Category model defaults — used when agents delegate tasks
        categories = {
          quick = {
            model = "google/antigravity-gemini-3-flash";
          };
          visual-engineering = {
            model = "google/antigravity-gemini-3.1-pro";
            variant = "high";
          };
          artistry = {
            model = "google/antigravity-gemini-3.1-pro";
            variant = "high";
          };
          writing = {
            model = "google/antigravity-gemini-3-flash";
          };
          unspecified-low = {
            model = "google/antigravity-claude-sonnet-4-6";
          };
          unspecified-high = {
            model = "github-copilot/gpt-5.4";
          };
          ultrabrain = {
            model = "github-copilot/gpt-5.4";
          };
          deep = {
            model = "github-copilot/gpt-5.3-codex";
          };
        };

        # Concurrency limits — prevent runaway parallel requests
        background_task = {
          providerConcurrency = {
            github-copilot = 3;
            google = 10;
          };
          modelConcurrency = {
            "google/antigravity-claude-opus-4-6-thinking" = 2;
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
      shellWrapperName = "y";
    };

    ripgrep = {
      enable = true;
    };

    # AI coding assistant - binary from llm-agents.nix, plugins auto-install to ~/.cache/opencode/
    # Update binary: nix flake update llm-agents && darwin-rebuild switch
    # Update plugins: just update-plugins && darwin-rebuild switch
    # Auth tokens: ~/.local/share/opencode/antigravity-accounts.json (run `opencode auth login`)
    opencode = {
      enable = true;
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      settings = {
        autoupdate = false; # Prevent binary self-update (managed by nix flake update)
        small_model = "google/antigravity-gemini-3-flash";
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
        # Provider models — only Antigravity (all Claude + Gemini through Google OAuth)
        # GPT-5.4 via github-copilot is auto-detected, no provider config needed
        provider = {
          google = {
            models = {
              # Gemini 3.1 Pro — visual-engineering, artistry, frontend
              "antigravity-gemini-3.1-pro" = {
                name = "Gemini 3.1 Pro (Antigravity)";
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
                variants = {
                  low = {
                    thinkingLevel = "low";
                  };
                  medium = {
                    thinkingLevel = "medium";
                  };
                  high = {
                    thinkingLevel = "high";
                  };
                };
              };
              # Gemini 3 Flash — explore, librarian, quick tasks, writing
              "antigravity-gemini-3-flash" = {
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
                variants = {
                  minimal = {
                    thinkingLevel = "minimal";
                  };
                  low = {
                    thinkingLevel = "low";
                  };
                  medium = {
                    thinkingLevel = "medium";
                  };
                  high = {
                    thinkingLevel = "high";
                  };
                };
              };
              # Claude Sonnet 4.6 — atlas, unspecified-low tasks
              "antigravity-claude-sonnet-4-6" = {
                name = "Claude Sonnet 4.6 (Antigravity)";
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
              # Claude Opus 4.6 Thinking — Sisyphus, prometheus, metis
              "antigravity-claude-opus-4-6-thinking" = {
                name = "Claude Opus 4.6 Thinking (Antigravity)";
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
                variants = {
                  low = {
                    thinkingConfig = {
                      thinkingBudget = 8192;
                    };
                  };
                  max = {
                    thinkingConfig = {
                      thinkingBudget = 32768;
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
