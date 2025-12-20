{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    inputs.repertoire-builder.nixosModules.container
    ./modules/networking.nix
    ./modules/monitoring.nix
    ./modules/security.nix
    ./modules/vaultwarden.nix
    ./modules/backup.nix
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Binary caches for faster builds
    extra-substituters = [
      "https://deploy-rs.cachix.org"
    ];
    extra-trusted-public-keys = [
      "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
    ];
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd.systemd.enable = true;
  };

  systemd.targets.multi-user.enable = true;

  networking.hostName = "oracle-0";


  time.timeZone = "America/Edmonton";
  i18n.defaultLocale = "en_CA.UTF-8";

  users = {
    mutableUsers = false;
    users.matt = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca" ];
    };
  };

  # Enable passwordless sudo.
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

  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    wget
    ghostty.terminfo
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = false; # Only allow SSH over Tailscale
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Secrets management
  age.secrets.tailscale-authkey.file = ../../secrets/tailscale-authkey.age;

  # Tailscale VPN
  # Note: tag:cloud is isolated - see tailscale-acl.json for policy
  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraUpFlags = [ "--advertise-tags=tag:cloud" ];
  };

  # Taildrive: Share root filesystem
  # Access via http://100.100.100.100:8080/<tailnet>/oracle-0/root
  systemd.services.taildrive-shares = {
    description = "Configure Taildrive shares";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for Tailscale to be connected
      while ! ${pkgs.tailscale}/bin/tailscale status --peers=false 2>/dev/null | grep -q "100\."; do
        sleep 2
      done
      ${pkgs.tailscale}/bin/tailscale drive share root /
    '';
  };

  # Netdata removed; see modules/monitoring.nix for Prometheus+Grafana

  services.caddy = {
    enable = true;
    globalConfig = ''
      auto_https off
    '';
    virtualHosts = {
      "http://cernohorsky.ca" = {
        listenAddresses = [ "127.0.0.1" ];
        extraConfig = ''
          respond "Matt's website will be here someday." 200
        '';
      };
      # stats.* removed; use metrics.cernohorsky.ca for Grafana
      "http://chess.cernohorsky.ca" = {
        listenAddresses = [ "127.0.0.1" ];
        extraConfig = ''
          reverse_proxy repertoire-builder:8090

          encode gzip

          header {
            X-Content-Type-Options "nosniff"
            X-Frame-Options "DENY"
            X-XSS-Protection "1; mode=block"
            Referrer-Policy "strict-origin-when-cross-origin"
          }
        '';
      };
    };
  };

  # Provide built frontend to the repertoire-builder container module
  services.repertoire-builder.webDist =
    inputs.repertoire-builder.packages.${pkgs.stdenv.hostPlatform.system}.web;


  # Configure nix for deployment
  nix.settings.trusted-users = [ "@wheel" ];

  # Disable autologin.
  services.getty.autologinUser = null;

  # Firewall moved to modules/security.nix

  # Additional container networking will be configured in repertoire-builder-container.nix

  # Disable documentation for minimal install.
  documentation.enable = false;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}
