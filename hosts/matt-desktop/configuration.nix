{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./modules/core.nix
    ./modules/nvidia.nix
    ./modules/hyprland.nix
    ./modules/gaming.nix
    ./modules/media.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2; # Faster boot menu

  networking.hostName = "matt-desktop";

  # Fix slow shutdown
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  users.users.matt = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca" ];
  };

  # Restic REST Server for receiving backups from oracle-0
  # Security: Tailscale ACLs restrict access to tag:cloud only, appendOnly prevents deletion
  services.restic.server = {
    enable = true;
    dataDir = "/backups/oracle-0/vaultwarden";
    listenAddress = "8000";
    appendOnly = true;
    extraFlags = [ "--no-auth" ];
  };

  # Stylix system-wide theming
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    # Gruvbox dark palette
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    # Wallpaper: Replace with path to your preferred image
    # Example: image = ./wallpapers/painting.jpg;
    # For now, using a generated Gruvbox gradient
    image = pkgs.runCommand "gruvbox-wallpaper.png" {
      nativeBuildInputs = [ pkgs.imagemagick ];
    } ''
      magick -size 3840x2160 \
        -define gradient:angle=135 \
        gradient:'#1d2021-#282828' \
        -blur 0x2 \
        $out
    '';

    # Fonts (Using JetBrains Mono for everything)
    fonts = {
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      sansSerif = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      serif = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        terminal = 13;
        applications = 11;
        desktop = 11;
        popups = 11;
      };
    };
    cursor = {
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-light";
      size = 24;
    };
  };

  # OpenSSH: Keep enabled for agenix host keys, but prefer Tailscale SSH for access
  services.openssh = {
    enable = true;
    openFirewall = false; # Not exposed to internet, Tailscale SSH preferred
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Passwordless sudo for matt (required for deploy-rs)
  security.sudo.extraRules = [
    {
      users = [ "matt" ];
      commands = [
        { command = "ALL"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # Secrets management
  age.secrets = {
    tailscale-authkey.file = ../../secrets/tailscale-authkey.age;
  };

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    openFirewall = true; # Allow UDP 41641 for direct connections
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraUpFlags = [ "--advertise-tags=tag:trusted" "--ssh" ];
  };

  # Taildrive: Share main drives
  # Access via http://100.100.100.100:8080/<tailnet>/matt-desktop/<share>
  systemd.services.taildrive-shares = {
    description = "Configure Taildrive shares";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    partOf = [ "tailscaled.service" ]; # Restart when tailscaled restarts
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for Tailscale to be connected
      while ! ${pkgs.tailscale}/bin/tailscale status --peers=false 2>/dev/null | grep -q "100\."; do
        sleep 2
      done
      ${pkgs.tailscale}/bin/tailscale drive share ssd /
      ${pkgs.tailscale}/bin/tailscale drive share hdd /mnt/hdd
    '';
  };

  # Firewall: Restic REST Server only via Tailscale (SSH handled by Tailscale SSH)
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8000 ];

  # Samba: Share root filesystem over direct ethernet connection
  # Note: Can't use "bind interfaces only" as smbd crashes if interface missing
  services.samba = {
    enable = true;
    nmbd.enable = false; # Use Avahi instead for macOS discovery
    winbindd.enable = false; # Not needed for simple file sharing
    settings = {
      global = {
        # Only allow connections from direct ethernet link-local range
        "hosts allow" = "169.254.";
        "hosts deny" = "ALL";
      };
      root = {
        path = "/";
        browseable = "yes";
        "read only" = "no";
        "force user" = "matt";
      };
    };
  };
  networking.firewall.interfaces."enp4s0".allowedTCPPorts = [ 445 ];

  # Avahi: Advertise Samba via mDNS/Bonjour for macOS Finder discovery
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles.smb = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
      </service-group>
    '';
  };

  # Backup directory for oracle-0 restic backups
  systemd.tmpfiles.rules = [
    "d /backups 0755 matt users -"
    "d /backups/oracle-0 0755 matt users -"
    "d /backups/oracle-0/vaultwarden 0755 restic-rest-server restic-rest-server -"
  ];

  # Local pruning of oracle-0 backups
  # oracle-0 can only append (REST server is append-only), matt-desktop prunes locally
  age.secrets.restic-password = {
    file = ../../secrets/restic-password.age;
    owner = "root";
    group = "root";
  };

  services.restic.backups.oracle-0-local-prune = {
    repository = "/backups/oracle-0/vaultwarden";
    passwordFile = config.age.secrets.restic-password.path;
    paths = [ ];

    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };

    # GFS retention policy (must match oracle-0 R2 backup)
    # hourly: 6 days of granular recovery (24 × 6hr intervals)
    # daily: 2 weeks, weekly: 2 months, monthly: 1 year, yearly: 2 years
    pruneOpts = [
      "--keep-hourly 24"
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
      "--keep-yearly 2"
    ];
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://deploy-rs.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
    ];
    trusted-users = [ "root" "@wheel" ];
  };

  # Fix Tailscale TPM issue after BIOS updates
  systemd.services.tailscaled.serviceConfig.Environment = [ "TS_NO_TPM=1" ];

  # Btrfs snapshot management for /home
  # Snapshots accessible at /btr_pool/@snapshots/@home.<date>
  services.btrbk.instances.home = {
    onCalendar = "daily";
    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = "7d 4w";
      volume."/btr_pool" = {
        subvolume."@home" = {
          snapshot_dir = "@snapshots";
        };
      };
    };
  };

  # Mount raw btrfs root for btrbk snapshot access
  fileSystems."/btr_pool" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" ];
  };

  system.stateVersion = "25.05";
}
