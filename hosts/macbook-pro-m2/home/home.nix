{
  pkgs,
  inputs,
  ...
}:

let
  runebender = pkgs.callPackage ../../../packages/runebender.nix { };

  # Bindings shared by normal and select mode; normal mode adds C-j/C-k below.
  helixModalKeys = {
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
in
{
  imports = [
    ../../../modules/home/opencode-v2.nix
    ../../../modules/home/tailscale-policy.nix
    ../../../modules/home/dev-templates.nix
    ../../../modules/home/uv-python.nix
    ../../../modules/home/zed.nix
  ];

  modules.home.opencodeV2.enable = true;
  modules.home.tailscalePolicy.enable = true;
  modules.home.devTemplates.enable = true;
  modules.home.uvPython.enable = true;
  modules.home.zed.enable = true;

  # Zed installs via the Homebrew cask (native bundle, self-updates);
  # Home Manager owns only the config (mutable, merged at activation).
  programs.zed-editor.package = null;

  home = {
    username = "matt";
    homeDirectory = "/Users/matt";
    stateVersion = "23.11";

    file = {
      ".hushlogin".text = ""; # Disable login messages in the terminal.
      "Developer/.keep".text = ""; # The Developer directory has a cool icon on macOS.
      # Surface the nix-built bundle to Finder/Spotlight (the store itself
      # is not indexed).
      "Applications/Runebender.app".source = "${runebender}/Applications/Runebender.app";
      # Make the helix background transparent.
      ".config/helix/themes/custom.toml".text = ''
        inherits = "gruvbox_dark_hard"
        "ui.background" = {}
      '';
      ".config/zellij/config.kdl".source = ./config.kdl;
    };

    packages = with pkgs; [
      lazydocker
      tree
      fd
      bottom
      hyperfine
      gh

      bitwarden-desktop
      runebender # Font editor (custom package in ../../../packages)

      nixd
      nixfmt

      nodejs # Node-targeted npm CLIs and language servers
    ];

    shellAliases = {
      lg = "lazygit";
      ld = "lazydocker";
      zj = "zellij";
    };
  };

  programs.home-manager.enable = true;

  manual = {
    manpages.enable = false;
    html.enable = false;
    json.enable = false;
  };

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
          normal = helixModalKeys // {
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
          };
          select = helixModalKeys;
        };
      };
      languages = {
        language = [
          {
            name = "nix";
            formatter.command = "nixfmt";
            language-servers = [ "nixd" ];
          }
          {
            name = "rust";
            formatter.command = "rustfmt";
          }
        ];
        language-server = {
          rust-analyzer = {
            config = {
              files = {
                watcher = "client";
              };
            };
          };
        };
      };
    };

    git = {
      enable = true;
      signing.format = "openpgp";
      settings = {
        user.name = "Matt Cernohorsky";
        user.email = "matt@cernohorsky.ca";
        github.user = "mcernohorsky";
        init.defaultBranch = "main";
      };
    };

    zsh = {
      enable = true;
      profileExtra = ''
        # OrbStack CLI integration (kept declarative so Home Manager owns .zprofile).
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
    bash.enable = true;
    nushell = {
      enable = true;
      settings = {
        show_banner = false;
      };
      extraEnv = ''
        let determinate_nix_bin_dir = "/nix/var/nix/profiles/default/bin"
        let nix_darwin_system_bin_dir = "/run/current-system/sw/bin"
        $env.PATH = (
          $env.PATH
          | prepend $nix_darwin_system_bin_dir
          | prepend $determinate_nix_bin_dir
          | uniq
        )
      '';
    };

    ghostty = {
      enable = true;
      # System app bundle is installed outside Nix; only manage the config.
      package = null;
      settings = {
        auto-update = "off";
        theme = "light:Gruvbox Light,dark:Gruvbox Dark Hard";
        font-family = [
          "NordwandMono Nerd Font Mono"
          "Noto Color Emoji"
        ];
        background-opacity = 0.95;
        background-blur = 10;
        macos-option-as-alt = "left";
        mouse-hide-while-typing = true;
        command = "${pkgs.nushell}/bin/nu";
        quick-terminal-animation-duration = 0;
        macos-non-native-fullscreen = true;
      };
    };

    starship.enable = true;

    atuin = {
      enable = true;
      # Atuin 18.19 emits two Nushell keybindings with the same name when both
      # Ctrl-R and Up are enabled, which Nushell 0.115 warns about. Keep the
      # history search on Ctrl-R and let Up use Nushell's native history.
      flags = [ "--disable-up-arrow" ];
    };

    nix-index.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      config = {
        warn_timeout = 0;
      };
    };

    fzf = {
      enable = true;
      # Atuin owns Ctrl-R; keep FZF enabled without a shadowed history binding.
      historyWidget.command = "";
    };

    zellij.enable = true;

    zoxide.enable = true;

    bat.enable = true;

    jujutsu.enable = true;

    lazygit.enable = true;

    yazi = {
      enable = true;
      shellWrapperName = "y";
    };

    ripgrep.enable = true;

  };
}
