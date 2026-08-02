{ pkgs, ... }:
{
  system = {
    stateVersion = 5;
    primaryUser = "matt";
  };

  determinateNix = {
    enable = true;
    customSettings = {
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
      eval-cores = 0;

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
    determinateNixd = {
      builder.state = "enabled";
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
    ];

    casks = [
      "affinity"
      "aqua-voice"
      "betterdisplay"
      "chatgpt"
      "blender"
      "codex-app"
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
      "nvidia-geforce-now"
      "opencode-desktop"
      "orbstack"
      "obsidian"
      "qbittorrent"
      "raycast"
      "rectangle"
      "shottr"
      "stats"
      "steam"
      "surfshark"
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
      orientation = "bottom";
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

  # Tailscale is the management path to the NixOS hosts. Keep its daemon alive
  # across crashes just like other long-running launchd services.
  launchd.daemons.tailscaled.serviceConfig = {
    KeepAlive = true;
    ThrottleInterval = 5;
  };

  # Enable Tailscale SSH (nix-darwin doesn't have extraUpFlags).
  # Do not run `tailscale up` during every activation: it can block forever when
  # the machine is not authenticated. `set` changes only the SSH preference.
  system.activationScripts.postActivation.text = ''
    if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
      ${pkgs.tailscale}/bin/tailscale set --ssh || \
        echo "Tailscale is running but SSH preference could not be updated"
    else
      echo "Tailscale is not authenticated; skipping Tailscale SSH preference"
    fi
  '';
}
