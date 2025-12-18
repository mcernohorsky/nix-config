{ pkgs, ... }:
{
  system = {
    stateVersion = 5;
    primaryUser = "matt";
  };

  nix = {
    enable = true;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@admin"
        "matt"
      ];
      download-buffer-size = 524288000; # 500 MiB

      # Binary caches for faster builds
      extra-substituters = [
        "https://helix.cachix.org"
        "https://cache.numtide.com" # nix-ai-tools (amp, claude-code, opencode, etc.)
      ];
      extra-trusted-public-keys = [
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 0;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  users.users.matt = {
    home = "/Users/matt";
  };

  programs.bash.enable = true;
  programs.zsh.enable = true;

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    taps = [
      "homebrew/core"
      "homebrew/cask"
      "homebrew/bundle"
    ];

    casks = [
      "affinity"
      # "android-studio"
      "betterdisplay"
      "blender"
      "cursor"
      "discord"
      "ghostty"
      "handy"
      # "hammerspoon"
      "helium-browser"
      "iina"
      "imageoptim"
      "inkscape"
      "itsycal"
      "keka"
      # "kicad"
      "magicavoxel"
      "monodraw"
      "orbstack"
      "qbittorrent"
      "raycast"
      "rectangle"
      "shottr"
      "stats"
      "steam"
      "surfshark"
      "zen"
      "orion"
      "readest"
      "raindropio"
    ];

    masApps = {
      "Color Picker" = 1545870783;
      "Dropover" = 1355679052;
      "Kindle" = 302584613;
      "Klack" = 6446206067;
      # "Xcode" = 497799835;
      # "Microsoft Excel" = 462058435;
      # "Microsoft Word" = 462054704;
      # "Pages" = 409201541;
    };

    # Manually Installed Apps:
    # BatFi
    # Excel
    # Word
  };

  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      mru-spaces = false;
      orientation = "right";
      show-recents = false;
      static-only = true;
    };

    finder = {
      FXDefaultSearchScope = "SCcf"; # Search the current folder
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv"; # Use list view
      NewWindowTarget = "iCloud Drive";
      ShowPathbar = true;
    };

    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSWindowShouldDragOnGesture = true;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  system.activationScripts.extraActivation.text = ''
    # Install Rosetta
    if ! pkgutil --pkgs | grep -q "com.apple.pkg.RosettaUpdateAuto"; then
      softwareupdate --install-rosetta --agree-to-license
    fi

    # Set battery brightness behavior
    sudo pmset -b lessbright 0
  '';

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  services.tailscale.enable = true;
}
