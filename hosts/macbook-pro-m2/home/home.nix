{ pkgs, inputs, ... }:
{
  # disabledModules = [ "programs/ghostty.nix" ];
  imports = [ ];

  # User Configuration
  home = {
    username = "matt";
    homeDirectory = "/Users/matt";
    stateVersion = "23.11";

    # Add scripts to the PATH.
    sessionPath = [ "$HOME/.local/bin" ];
    sessionVariables = {
      DIRENV_WARN_TIMEOUT = "0";
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
    };

    packages = with pkgs; [
      claude-code
      gemini-cli
      lazydocker
      tree
      fd
      bottom
      hyperfine

      tailscale
      bitwarden-desktop

      nixd
      nixfmt-rfc-style

      # fonts
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      inter
      merriweather
      roboto
    ];

    shellAliases = {
      lg = "lazygit";
      ld = "lazydocker";
      zj = "zellij";
    };
  };

  programs.home-manager.enable = true;

  programs = {
    helix = {
      enable = true;
      package = inputs.helix-master.packages.${pkgs.system}.default;
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
      userName = "Matt Cernohorsky";
      userEmail = "matt@cernohorsky.ca";
      extraConfig = {
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
        theme = "light:GruvboxLight,dark:GruvboxDarkHard";
        background = "#1d2021"; # Add a little blue.
        background-opacity = 0.95;
        background-blur = 10;
        macos-option-as-alt = "left";
        mouse-hide-while-typing = true;
        command = "${pkgs.bashInteractive}/bin/bash -i -l -c 'exec nu'";
        keybind = "global:opt+ =toggle_quick_terminal";
        quick-terminal-animation-duration = 0;
        macos-non-native-fullscreen = true;
        # macos-icon = "retro";
      };
    };

    # CLI Tools
    oh-my-posh = {
      enable = true;
      useTheme = "agnoster";
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

    opencode = {
      enable = true;
    };
  };
}
