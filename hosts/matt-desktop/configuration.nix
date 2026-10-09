{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./modules/backups.nix
    ./modules/core.nix
    ./modules/cosmic.nix
    ./modules/desktop-services.nix
    ./modules/fan-control.nix
    ./modules/file-sharing.nix
    ./modules/gaming.nix
    ./modules/media.nix
    ./modules/nvidia.nix
  ];

  networking.hostName = "matt-desktop";
  system.stateVersion = "25.05";
  nixpkgs.config.allowUnfree = true;

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
    timeout = 2;
  };

  # Unlock the LUKS2 root with its enrolled TPM2 token; the passphrase still works.
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];

  # For `just deploy-oracle desktop`; emulated builds are slow.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  nix.settings.eval-cores = 0;

  # Fix slow shutdown
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";

  # The OpenCode AppImage stays writable so its updater works.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  services.udev.packages = [
    pkgs.solaar
    pkgs.asdbctl
  ];

  users.users.matt = {
    # Keep T3 Code's user service running after logout.
    linger = true;
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "i2c"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /home/matt/Developer 0755 matt users -"
    "d /home/matt/.local/opt/opencode 0755 matt users -"
  ];

  # Kept for agenix host keys; access goes through Tailscale SSH.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  age.secrets = {
    tailscale-authkey.file = ../../secrets/tailscale-authkey.age;
    tailscale-policy-oauth = {
      file = ../../secrets/tailscale-policy-oauth.age;
      owner = "matt";
    };
    # Installed into ~/.ssh by Home Manager for desktop-to-Mac SSH.
    ssh-user-key = {
      file = ../../secrets/ssh-id-ed25519.age;
      owner = "matt";
    };
  };

  services.tailscale = {
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraUpFlags = [
      "--advertise-tags=tag:trusted"
      "--operator=matt"
    ];
  };
  # Fix Tailscale TPM state invalidation after BIOS updates.
  systemd.services.tailscaled.environment.TS_NO_TPM = "1";

  # Keep the management path up across live activations.
  systemd.services.NetworkManager.restartIfChanged = false;
}
