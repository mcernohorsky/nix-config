# Baseline shared by the NixOS hosts.
{ lib, ... }:
{
  imports = [ ./tailscale.nix ];

  nix = {
    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://deploy-rs.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkDefault "--delete-older-than 30d";
    };
  };

  # Neither host has disk swap. zram gives idle pages a compressed place to go
  # before the OOM killer runs; it is cheap to swap to, so the kernel docs
  # recommend high swappiness and no readahead.
  zramSwap.enable = true;
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  time.timeZone = "America/Edmonton";
  i18n.defaultLocale = "en_CA.UTF-8";

  users.users.matt = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ (import ../../lib/keys.nix).matt ];
  };

  # deploy-rs activation and unattended agent sessions need passwordless sudo.
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

  # Keep the management path up across live activations.
  systemd.services.systemd-resolved.restartIfChanged = false;
}
