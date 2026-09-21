{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # NASA Artemis II Earthset, original 5568×3712 image from NASA's Flickr.
  # Single source of truth for the COSMIC desktop.
  wallpaperImage = pkgs.fetchurl {
    name = "artemis-ii-earthset.jpg";
    url = "https://www.flickr.com/photo_download.gne?id=55192132107&secret=00dc598014&size=o&source=photoPageEngagement";
    hash = "sha256-nsaMkJZmtPQjmkQcWbpZ0DNZvGSzUKzw/1LxhFwGScM=";
  };
in

{

  home-manager.extraSpecialArgs = {
    inherit inputs wallpaperImage;
  };

  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./modules/core.nix
    ./modules/nvidia.nix
    ./modules/fan-control.nix
    ./modules/desktop-services.nix
    ./modules/gaming.nix
    ./modules/media.nix
    ./modules/opencode-v2.nix
    ./modules/cosmic.nix
    ../../modules/nixos/tailscale-recover.nix
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
    timeout = 2;
  };

  # Allow the systemd initrd to unlock the LUKS2 system volume with its
  # enrolled TPM2 token. The existing passphrase slot remains available.
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];

  networking.hostName = "matt-desktop";

  # The official OpenCode AppImage remains writable so its updater can
  # follow the stable channel outside the Nix store.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Fix slow shutdown
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";

  nixpkgs.config.allowUnfree = true;

  services.udev.packages = [
    pkgs.solaar
    pkgs.asdbctl
  ];

  users.users.matt = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "i2c"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca"
    ];
  };

  # Restic REST Server for receiving backups from oracle-0
  # Security: Tailscale ACLs restrict access to tag:cloud only, appendOnly prevents deletion
  services.restic.server = {
    enable = true;
    dataDir = "/backups/oracle-0/vaultwarden";
    appendOnly = true;
    extraFlags = [ "--no-auth" ];
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

  # Passwordless sudo for matt
  # Required by deploy-rs for remote NixOS activation.
  # This overrides wheelNeedsPassword from core.nix for user matt specifically.
  security.sudo.extraRules = [
    {
      users = [ "matt" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  age.secrets = {
    tailscale-authkey.file = ../../secrets/tailscale-authkey.age;
    restic-password = {
      file = ../../secrets/restic-password.age;
      owner = "restic";
      group = "restic";
      mode = "0400";
    };
    tailscale-policy-oauth = {
      file = ../../secrets/tailscale-policy-oauth.age;
      owner = "matt";
      group = "users";
      mode = "0400";
    };
    # matt's personal SSH private key (desktop client identity for Mac-bound
    # SSH). Owner matt: Home Manager activation installs it into ~/.ssh.
    ssh-user-key = {
      file = ../../secrets/ssh-id-ed25519.age;
      owner = "matt";
      group = "users";
      mode = "0400";
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true; # Allow UDP 41641 for direct connections
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    # This file contains an OAuth client secret. OAuth-provisioned nodes are
    # ephemeral by default, which lets the control plane delete the desktop
    # after it has been offline. Keep this long-lived machine persistent and
    # able to recover without interactive device approval.
    authKeyParameters = {
      ephemeral = false;
      preauthorized = true;
    };
    extraUpFlags = [
      "--advertise-tags=tag:trusted"
      "--ssh"
    ];
  };

  # Taildrive: Share main drives
  # Access via http://100.100.100.100:8080/<tailnet>/matt-desktop/<share>
  systemd.services.taildrive-shares = {
    description = "Configure Taildrive shares";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "30s";
      ExecStart = [
        "${pkgs.tailscale}/bin/tailscale drive share ssd /"
        "${pkgs.tailscale}/bin/tailscale drive share hdd /mnt/hdd"
      ];
    };
  };

  # Firewall: Restic REST Server only via Tailscale (SSH handled by Tailscale SSH)
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    8000
    13378
  ];

  # Samba: Share root filesystem over direct ethernet connection
  # Note: Can't use "bind interfaces only" as smbd crashes if interface missing
  services.samba = {
    enable = true;
    nmbd.enable = false; # Use Avahi instead for macOS discovery
    winbindd.enable = false; # Not needed for simple file sharing
    settings = {
      global = {
        # Only allow connections from direct ethernet link-local range (IPv4 and IPv6)
        "hosts allow" = "169.254. fe80::/10";
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

  # Avahi: mDNS for Samba discovery from macOS Finder (enp4s0 only)
  # NOTE: Restricted to direct ethernet link. For general mDNS (printers, Chromecast),
  # remove allowInterfaces or add your main network interface.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    allowInterfaces = [ "enp4s0" ];
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

  systemd.tmpfiles.rules = [
    "d /backups 0755 matt users -"
    "d /backups/oracle-0 0755 matt users -"
    "d /backups/oracle-0/vaultwarden 0755 restic restic -"
  ];

  # Local pruning of oracle-0 backups
  # oracle-0 can only append (REST server is append-only), matt-desktop prunes locally
  services.restic.backups.oracle-0-local-prune = {
    repository = "/backups/oracle-0/vaultwarden";
    passwordFile = config.age.secrets.restic-password.path;
    user = "restic";

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

    # Validate repository metadata after pruning so ownership or index errors
    # fail the weekly maintenance job instead of remaining silent.
    checkOpts = [ "--with-cache" ];
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      eval-cores = 0;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://deploy-rs.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Keep the management path stable across live activations.
  systemd.services.NetworkManager.restartIfChanged = false;
  systemd.services.systemd-resolved.restartIfChanged = false;
  systemd.services.tailscaled = {
    restartIfChanged = false;
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      # Avoid exhausting systemd's default five-start burst during a persistent
      # failure; retry slowly until the underlying problem is corrected.
      RestartSec = lib.mkForce "5s";
      # Fix Tailscale TPM state invalidation after BIOS updates.
      Environment = [ "TS_NO_TPM=1" ];
    };
  };

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
    options = [
      "subvolid=5"
      "noatime"
    ];
  };

  system.stateVersion = "25.05";
}
