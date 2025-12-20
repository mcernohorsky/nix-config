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

  users.users.matt = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca" ];
  };

  # Stylix system-wide theming
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    # Gruvbox dark palette
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    # Generate a simple gruvbox-colored wallpaper
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

  services.openssh = {
    enable = true;
    openFirewall = false; # Only allow SSH over Tailscale
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Secrets management
  age.secrets.tailscale-authkey.file = ../../secrets/tailscale-authkey.age;

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    openFirewall = true; # Allow UDP 41641 for direct connections
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraUpFlags = [ "--advertise-tags=tag:trusted" ];
  };

  # Taildrive: Share main drives
  # Access via http://100.100.100.100:8080/<tailnet>/matt-desktop/<share>
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
      ${pkgs.tailscale}/bin/tailscale drive share ssd /
      ${pkgs.tailscale}/bin/tailscale drive share hdd /mnt/hdd
    '';
  };

  # Firewall: SSH only via Tailscale
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];

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

  system.stateVersion = "25.05";
}
