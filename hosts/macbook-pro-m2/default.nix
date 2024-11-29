{ pkgs, ... }:
{
  system.stateVersion = 5;

  services.nix-daemon.enable = true;
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 0; Minute = 0; };
      options = "--delete-older-than 30d";
    };
  };

  users.users.matt = {
    home = /Users/matt;
  };

  # Fish shell integration is enabled in home manager and nix-darwin to make sure the PATH is set correctly for fish.
  programs.fish.enable = true;

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
      "nikitabobko/tap"
    ];

    casks = [
      # "aerospace"
      # "android-studio"
      "arc"
      "betterdisplay"
      # "bettertouchtool"
      "blender"
      # "dbngin"
      "discord"
      "gzdoom"
      # "hammerspoon"
      "iina"
      "imageoptim"
      "inkscape"
      "itsycal"
      "keka"
      # "kicad"
      "maccy"
      "monodraw"
      "orbstack"
      "raycast"
      "rectangle"
      "shottr"
      "stats"
      "steam"
      # "surfshark"
      # "tableplus"
      # "qbittorrent"
      # "warp"
      # "zed"
      # "zen-browser"
    ];

    masApps = {
      "Color Picker" = 1545870783;
      "Dropover" = 1355679052;
      "Kindle" = 302584613;
      "Klack" = 6446206067;
      "Microsoft Excel" = 462058435;
      "Microsoft Word" = 462054704;
      "Perplexity" = 6714467650;
      "Xcode" = 497799835;
      # "Pages" = 409201541;
    };

    # Manually Installed Apps:
    # BatFi
    # rcmd
    # Windsurf
    # Ghostty
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
      FXPreferredViewStyle = "Nlsv";  # Use list view
      NewWindowTarget = "iCloud Drive";
      ShowPathbar = true;
    };

    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
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
  security.pam.enableSudoTouchIdAuth = true;
}