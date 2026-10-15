{
  config,
  inputs,
  pkgs,
  ...
}:
let
  mono = import ../../lib/mono-font.nix { inherit pkgs; };

  # Third-party casks, which also need their tap and a trust entry.
  tapCasks = [
    "anomalyco/tap/hex"
    "abue-ammar/tinycast/tinycast"
    "nolight132/tap/sonora"
  ];
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = 5;
    primaryUser = "matt";
  };

  determinateNix = {
    enable = true;
    customSettings = {
      trusted-users = [
        "root"
        "@admin"
        "matt"
      ];
      download-buffer-size = 524288000; # 500 MiB
      eval-cores = 0;
      extra-substituters = [
        "https://helix.cachix.org"
      ];
      extra-trusted-public-keys = [
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      ];
    };
    determinateNixd = {
      builder = {
        state = "enabled";
        # Oracle's aarch64 closure is large; give the native Linux VM enough
        # memory to avoid reclaim thrash while retaining Determinate's
        # recommended single-CPU configuration.
        memoryBytes = 17179869184; # 16 GiB
        cpuCount = 1;
      };
    };
  };

  age.identityPaths = [ "/Users/matt/.ssh/id_ed25519" ];

  # Read by the tailscale-policy helper.
  age.secrets.tailscale-policy-oauth = {
    file = ../../secrets/tailscale-policy-oauth.age;
    owner = "matt";
    mode = "0400";
  };

  fonts.packages = with pkgs; [
    nordwand-mono
    maple-mono.NF-unhinted
    mono.package
    mono.term.package
    nerd-fonts.jetbrains-mono
    iosevka
    inter
    merriweather
    roboto
  ];

  users.users.matt = {
    home = "/Users/matt";
    openssh.authorizedKeys.keys = [ (import ../../lib/keys.nix).matt ];
  };

  programs.bash.enable = true;
  programs.zsh.enable = true;

  # Nix only declares which apps are installed. Homebrew owns its taps and app
  # versions (brew-upgrade below), so app updates never need a deploy.
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "matt";
    mutableTaps = true;
    autoMigrate = true;
    trust.casks = tapCasks;
  };

  homebrew = {
    enable = true;
    # Deploys only install missing apps and zap removed ones.
    onActivation.cleanup = "zap";

    taps = map dirOf tapCasks;

    casks = tapCasks ++ [
      "betterdisplay"
      "bitwarden"
      "blender"
      "chatgpt"
      "claude"
      "cursor"
      "discord"
      "ghostty"
      "helium-browser"
      "iina"
      "imageoptim"
      "itsycal"
      "jellyfin-media-player"
      "keka"
      "magicavoxel"
      "monodraw"
      "orbstack"
      "orion"
      "qbittorrent"
      "raindropio"
      "readest"
      "rectangle"
      "shottr"
      "stats"
      "steam"
      "surfshark"
      "t3-code@nightly"
      "zed"
    ];

    masApps = {
      "Color Picker" = 1545870783;
      "Dropover" = 1355679052;
      "Kindle" = 302584613;
      "Klack" = 6446206067;
    };
  };

  # Casks that update themselves (auto_updates) are left to their own updaters.
  launchd.user.agents.brew-upgrade = {
    path = [
      "/opt/homebrew/bin"
      "/usr/bin"
      "/bin"
    ];
    script = ''
      brew update
      brew upgrade
      # Sonora is ad-hoc signed and its cask does not clear quarantine itself.
      xattr -dr com.apple.quarantine /Applications/Sonora.app || true
    '';
    serviceConfig = {
      StartCalendarInterval = [
        {
          Hour = 6;
          Minute = 0;
        }
      ];
      StandardOutPath = "/tmp/brew-upgrade.log";
      StandardErrorPath = "/tmp/brew-upgrade.log";
    };
  };

  # Simulator devices live on x9-pro (CoreSimulatorService has Full Disk
  # Access), but runtimes stay internal and each Xcode beta leaves the old one.
  launchd.user.agents.simulator-prune = {
    path = [ "/usr/bin" ];
    script = ''
      xcrun simctl delete unavailable
      xcrun simctl runtime delete --outdated
      xcrun simctl runtime delete --unusable
    '';
    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 5;
          Minute = 30;
        }
      ];
      StandardOutPath = "/tmp/simulator-prune.log";
      StandardErrorPath = "/tmp/simulator-prune.log";
    };
  };

  # Determinate Nixd collects garbage, but every kept system generation is a
  # GC root, so without pruning the store grew to 155 generations and 93 GB.
  launchd.daemons.nix-prune-generations = {
    path = [ "/nix/var/nix/profiles/default/bin" ];
    script = "nix-collect-garbage --delete-older-than 14d";
    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 5;
          Minute = 0;
        }
      ];
      StandardOutPath = "/var/log/nix-prune-generations.log";
      StandardErrorPath = "/var/log/nix-prune-generations.log";
    };
  };

  # macOS no longer runs periodic's clean-tmps, so /tmp only empties on reboot
  # while agent scratch builds add ~25 GB a day. Remove whole top-level
  # entries with nothing modified for 3 days, so live checkouts and cargo
  # targets are never left half-deleted.
  launchd.daemons.tmp-sweep = {
    script = ''
      for entry in /private/tmp/* /private/tmp/.[!.]*; do
        [ -e "$entry" ] && [ ! -S "$entry" ] || continue
        case "''${entry##*/}" in
          com.apple.* | launchd* | tmux-* | .X* | .ICE-unix | powerlog) continue ;;
        esac
        recent=$(find "$entry" \( -mtime -3 -o -ctime -3 \) -print -quit 2>/dev/null)
        [ -n "$recent" ] || rm -rf -- "$entry"
      done
    '';
    serviceConfig = {
      StartCalendarInterval = [
        {
          Hour = 4;
          Minute = 30;
        }
      ];
      StandardOutPath = "/var/log/tmp-sweep.log";
      StandardErrorPath = "/var/log/tmp-sweep.log";
    };
  };

  system.defaults = {
    CustomUserPreferences.NSGlobalDomain.NSFixedPitchFont = mono.family;

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
    # Mic/dictation key -> F13 so Hex can see it as a normal shortcut.
    # hidutil: 0xC000000CF -> 0x700000068. Merges with the Caps Lock remap.
    userKeyMapping = [
      {
        HIDKeyboardModifierMappingSrc = 51539607759;
        HIDKeyboardModifierMappingDst = 30064771176;
      }
    ];
  };

  system.activationScripts.extraActivation.text = ''
    # nix-homebrew creates the Intel prefix but does not install Rosetta.
    if ! pkgutil --pkgs | grep -q "com.apple.pkg.RosettaUpdateAuto"; then
      softwareupdate --install-rosetta --agree-to-license
    fi

    # AC: 30m display off (~25m dim), never sleep, disable standby/powernap for SSH access
    pmset -c displaysleep 30 sleep 0 standby 0 powernap 0
    # Battery: 5m display off (~4m dim), sleep 1m after
    pmset -b displaysleep 5 sleep 1 lessbright 0
  '';

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Passwordless sudo for unattended agent sessions, as on the NixOS hosts.
  security.sudo.extraConfig = ''
    matt ALL=(root) NOPASSWD: ALL
  '';

  networking.hostName = "macbook-pro-m2";
  networking.computerName = config.networking.hostName;

  services.tailscale.enable = true;

  # Apple OpenSSH answers tailnet port 22 instead of Tailscale SSH: tailnet
  # ssh rules cannot address an untagged user-owned device.
  services.openssh.enable = true;

  launchd.daemons.tailscaled.serviceConfig = {
    KeepAlive = true;
    ThrottleInterval = 5;
  };

  # Keep the Tailscale SSH server off (see services.openssh). nix-darwin has
  # no extraUpFlags, and `tailscale up` can block when unauthenticated.
  system.activationScripts.postActivation.text = ''
    if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
      ${pkgs.tailscale}/bin/tailscale set --ssh=false || \
        echo "Tailscale is running but SSH preference could not be updated"
    else
      echo "Tailscale is not authenticated; skipping Tailscale SSH preference"
    fi
  '';
}
