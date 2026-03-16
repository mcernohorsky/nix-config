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
        "https://cache.numtide.com" # llm-agents (amp, claude-code, opencode, etc.)
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
      "betterdisplay"
      "chatgpt"
      "blender"
      "cursor"
      "discord"
      "ghostty"
      "handy"
      "helium-browser"
      "iina"
      "imageoptim"
      "inkscape"
      "itsycal"
      "jellyfin-media-player"
      "keka"
      "magicavoxel"
      "monodraw"
      "orbstack"
      "obsidian"
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
    };
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

    # Power Management
    # AC: 30m display off (~25m dim), never sleep, disable standby/powernap for SSH access
    sudo pmset -c displaysleep 30 sleep 0 standby 0 powernap 0
    # Battery: 5m display off (~4m dim), sleep 1m after
    sudo pmset -b displaysleep 5 sleep 1 lessbright 0
  '';

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  networking.hostName = "macbook-pro-m2";
  networking.computerName = "macbook-pro-m2";

  services.tailscale.enable = true;

  # Enable Tailscale SSH (nix-darwin doesn't have extraUpFlags)
  # Also configure Tailscale Serve for Portal web UI (accessible at https://macbook-pro-m2.tailc41cf5.ts.net)
  system.activationScripts.postActivation.text = ''
    ${pkgs.tailscale}/bin/tailscale up --ssh

    # Configure Tailscale Serve for Portal (mobile-first OpenCode UI)
    # Only configure if Tailscale is logged in and running
    if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
      echo "Configuring Tailscale Serve for Portal..."
      ${pkgs.tailscale}/bin/tailscale serve --bg http://127.0.0.1:3000
    fi
  '';
}
