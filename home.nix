{pkgs, ...}: {
  imports = [ ];

  # User Configuration
  home = {
    username = "matt";
    homeDirectory = /Users/matt;
    stateVersion = "23.11";
    
    file.".hushlogin".text = ""; # Disable login messages in the terminal
    
    packages = with pkgs; [
      lazydocker
      tree
    ];
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
