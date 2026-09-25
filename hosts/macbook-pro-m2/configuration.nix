{
  config,
  inputs,
  pkgs,
  ...
}:
let
  preferredMono = import ../../lib/mono-font.nix { inherit pkgs; };
  nordwand-mono = pkgs.callPackage ../../packages/nordwand-mono.nix {
    src = inputs.nordwand-mono;
  };
in
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

  nixpkgs.config.allowUnfree = true;

  age.identityPaths = [ "/Users/matt/.ssh/id_ed25519" ];

  # Tailscale API OAuth client (policy_file scope) for programmatic ACL
  # management. Decrypted for matt so agent sessions can mint short-lived
  # API tokens without interactive logins.
  age.secrets.tailscale-policy-oauth = {
    file = ../../secrets/tailscale-policy-oauth.age;
    owner = "matt";
    mode = "0400";
  };

  fonts.packages = with pkgs; [
    nordwand-mono
    maple-mono.NF-unhinted
    preferredMono.package
    preferredMono.term.package
    nerd-fonts.jetbrains-mono
    iosevka
    inter
    merriweather
    roboto
  ];

  users.users.matt = {
    home = "/Users/matt";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP"
    ];
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

    # Mirror nix-homebrew's pinned taps so the Brewfile agrees with them.
    taps = builtins.attrNames config.nix-homebrew.taps;

    casks = [
      # Third-party tap (pinned via nix-homebrew.taps in flake.nix).
      "anomalyco/tap/hex"
      "abue-ammar/tinycast/tinycast"
      "affinity"
      "betterdisplay"
      "blender"
      "chatgpt"
      "claude"
      "cursor"
      "discord"
      "ghostty"
      "helium-browser"
      "iina"
      "imageoptim"
      "inkscape"
      "itsycal"
      "jellyfin-media-player"
      "keka"
      "magicavoxel"
      "monodraw"
      "obsidian"
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
      "t3-code"
      "zed"
    ];

    masApps = {
      "Color Picker" = 1545870783;
      "Dropover" = 1355679052;
      "Kindle" = 302584613;
      "Klack" = 6446206067;
    };
  };

  system.defaults = {
    CustomUserPreferences.NSGlobalDomain.NSFixedPitchFont = preferredMono.family;

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

  # Passwordless sudo for unattended agent and remote administration sessions.
  # Keep this user-specific; the NixOS hosts use the same policy.
  security.sudo.extraConfig = ''
    matt ALL=(root) NOPASSWD: ALL
  '';

  networking.hostName = "macbook-pro-m2";
  networking.computerName = config.networking.hostName;

  services.tailscale.enable = true;

  # Plain OpenSSH (Apple Remote Login) answers tailnet port 22 on this host
  # instead of the Tailscale SSH intercept: ssh-rule destinations cannot
  # address a user-owned device without tagging it, so desktop-to-Mac SSH
  # is governed by filter rules (already allowed). Tailscale SSH remains
  # available as a client for outbound connections.
  services.openssh.enable = true;

  # Tailscale is the management path to the NixOS hosts. Keep its daemon alive
  # across crashes just like other long-running launchd services.
  launchd.daemons.tailscaled.serviceConfig = {
    KeepAlive = true;
    ThrottleInterval = 5;
  };

  # Keep the Tailscale SSH server off: Apple OpenSSH answers tailnet port
  # 22 instead (see services.openssh above), because the tailnet ssh policy
  # cannot address this user-owned device. nix-darwin doesn't have
  # extraUpFlags, hence `set` here.
  # Do not run `tailscale up` during every activation: it can block forever when
  # the machine is not authenticated. `set` changes only the SSH preference.
  system.activationScripts.postActivation.text = ''
    if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
      ${pkgs.tailscale}/bin/tailscale set --ssh=false || \
        echo "Tailscale is running but SSH preference could not be updated"
    else
      echo "Tailscale is not authenticated; skipping Tailscale SSH preference"
    fi
  '';
}
