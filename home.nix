{pkgs, ...}: {
  imports = [ ];

  # User Configuration
  home = {
    username = "matt";
    homeDirectory = /Users/matt;
    stateVersion = "23.11";
    
    # Add ghostty command to the PATH. This will probably be handled by Home Manager after Ghostty public release.
    sessionVariables = {
      PATH = "\${GHOSTTY_BIN_DIR:-}:\$PATH";
    };
    
    file = {
      ".hushlogin".text = ""; # Disable login messages in the terminal
      "Developer/.keep".text = ""; # The Developer directory has a cool icon on macOS.
      ".local/bin/dev" = {
        source = ./home/bin/dev;
        executable = true;
      };
    };
    
    packages = with pkgs; [
      lazydocker
      tree

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
    };
  };

  # Core System Programs
  programs.home-manager.enable = true;

  # Development Tools
  programs = {
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      
      extraLuaConfig = builtins.readFile ./home/neovim/init.lua;
    };

    helix = {
      enable = true;
    };

    zed-editor = {
      enable = true;
      extensions = [
        "html"
        "toml"
        "dockerfile"
        "docker-compose"
        "sql"
        "nix"
        "zig"
        "gleam"
        "haskell"
        "typst"
      ];
      userSettings = {
        vim_mode = true;
        theme = "Rosé Pine Moon";
        buffer_font_family = "JetBrainsMono Nerd Font"; 
        ui_font_family = "JetBrainsMono Nerd Font";
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        load_direnv = "shell_hook";
        terminal = {
          shell = {
            program = "fish";
          };
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

    # Shell and Terminal
    fish = {
      enable = true;
      interactiveShellInit = "set fish_greeting";
    };

    zsh = {
      enable = true;
    };

    bash = {
      enable = true;
    };
    
    # Terminal Emulator
    ghostty = {
      enable = true;
      
      settings = {
        font-family = "JetBrainsMono Nerd Font";
        font-size = 14;
        theme = "GruvboxDarkHard";
        background-opacity = 0.95;
        background-blur-radius = 20;
        macos-non-native-fullscreen = "visible-menu";
        macos-option-as-alt = "left";
        mouse-hide-while-typing = true;
        custom-shader-animation = true;
        window-vsync = true;
        command = "${pkgs.fish}/bin/fish";
        auto-update = "download";
        window-save-state = "always";
      };
    };

    # CLI Tools
    starship = {
      enable = true;
    };

    nix-index = {
      enable = true;
    };
    
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    fzf = {
      enable = true;
    };

    tmux = {
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
  };
}
