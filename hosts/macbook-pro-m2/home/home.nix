{
  pkgs,
  inputs,
  ...
}:

let
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
  home = {
    shellAliases = {
      ld = "lazydocker";
    };
    stateVersion = "23.11";

    file = {
      ".hushlogin".text = ""; # Disable login messages in the terminal.
      # Surface the Nix-built bundle to Finder and Spotlight.
      "Applications/Runebender.app".source = "${pkgs.runebender}/Applications/Runebender.app";
      # Make the helix background transparent.
      ".config/helix/themes/custom.toml".text = ''
        inherits = "gruvbox_dark_hard"
        "ui.background" = {}
      '';
    };

    packages = with pkgs; [
      lazydocker
      tree
      fd
      bottom
      hyperfine
      nixd
      nixfmt
    ];
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
          lsp.display-messages = true;
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
        language-server.rust-analyzer.config.files.watcher = "client";
      };
    };

    git.signing.format = "openpgp";

    zsh = {
      enable = true;
      profileExtra = ''
        # OrbStack CLI integration (kept declarative so Home Manager owns .zprofile).
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
    nushell.extraEnv = ''
      $env.PATH = (
        $env.PATH
        | prepend ["/nix/var/nix/profiles/default/bin" "/run/current-system/sw/bin"]
        | uniq
      )
    '';

    ghostty = {
      enable = true;
      package = null; # Homebrew cask
      settings = {
        auto-update = "off";
        background-opacity = 0.95;
        background-blur = 10;
        macos-option-as-alt = "left";
        mouse-hide-while-typing = true;
        quick-terminal-animation-duration = 0;
        macos-non-native-fullscreen = true;
      };
    };

    atuin = {
      enable = true;
      # Atuin 18.19 emits two Nushell keybindings with the same name when both
      # Ctrl-R and Up are enabled, which Nushell 0.115 warns about. Keep the
      # history search on Ctrl-R and let Up use Nushell's native history.
      flags = [ "--disable-up-arrow" ];
    };

    nix-index.enable = true;

    direnv.config.warn_timeout = 0;
    # Atuin owns Ctrl-R.
    fzf.historyWidget.command = "";
  };
}
