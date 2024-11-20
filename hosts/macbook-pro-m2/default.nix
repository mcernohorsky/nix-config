{ pkgs, ... }:
{

  system.stateVersion = 5;

  services.nix-daemon.enable = true;

  nix = {
    settings.experimental-features = "nix-command flakes";
    optimise.automatic = true;
  };
  
  # System-wide keyboard settings
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Removed user shell configurations as they're now in home-manager
  
  environment.systemPackages = with pkgs; [
    # Keeping minimal system-wide packages here
    # User packages moved to home-manager
  ];

  fonts = {
    packages = with pkgs; [
      inter
      jetbrains-mono
      merriweather
      roboto
      (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    ];
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate= true;
    onActivation.upgrade = true;
    casks = [
      "aerospace"
      # "android-studio"
      # "arc"
      "betterdisplay"
      # "bettertouchtool"
      "blender"
      # "dbngin"
      "discord"
      # "hammerspoon"
      "iina"
      "imageoptim"
      "inkscape"
      "itsycal"
      "keka"
      "maccy"
      "monodraw"
      "orbstack"
      "raycast"
      # "rectangle"
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
      "Klack" = 6446206067;
      "Xcode" = 497799835;
      "Dropover" = 1355679052;
      "Microsoft Excel" = 462058435;
      "Microsoft Word" = 462054704;
      "Kindle" = 302584613;
      "Perplexity" = 6714467650;
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
      orientation = "right";
      show-recents = false;
      static-only = true;
      mru-spaces = false;
    };
    finder = {
      FXPreferredViewStyle = "Nlsv";  # Use list view
      FXDefaultSearchScope = "SCcf"; # Search the current folder
      ShowPathbar = true;
      FXEnableExtensionChangeWarning = false;
      NewWindowTarget = "iCloud Drive";
    };
    NSGlobalDomain.KeyRepeat = 2;
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.AppleShowAllExtensions = true;
  };

  system.activationScripts.extraActivation.text = ''
    if ! pkgutil --pkgs | grep -q "com.apple.pkg.RosettaUpdateAuto"; then
      softwareupdate --install-rosetta --agree-to-license
    fi
  '';

  security.pam.enableSudoTouchIdAuth = true;
  
}