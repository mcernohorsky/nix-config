{ config, lib, pkgs, ... }:

let
  coolerControlConfig = pkgs.writeText "matt-desktop-coolercontrol.toml"
    (builtins.readFile ./coolercontrol-profiles.toml);
in

{
  # The in-tree NCT6683 driver is present on this kernel, but it does not
  # expose this board's Super I/O controller. Use the Nix-packaged NCT6687-R
  # driver and load it at boot so hwmon/PWM discovery is reproducible.
  boot.extraModulePackages = [ config.boot.kernelPackages.nct6687d ];
  boot.kernelModules = [ "nct6687" ];

  # CoolerControl owns the runtime control loop. Its NixOS module only exposes
  # the enable switch, so keep the measured profile graph and channel
  # assignments declarative in the daemon's normal writable config file.
  programs.coolercontrol.enable = true;

  # The daemon persists its config under /etc/coolercontrol and needs to be
  # able to update it through its API. Seed the writable file at service start
  # from Nix rather than symlinking it read-only into the store. Certificates,
  # authentication state, and runtime session data remain daemon-managed.
  systemd.services.coolercontrold.serviceConfig.ExecStartPre = lib.mkBefore [
    "${pkgs.coreutils}/bin/install -D -m 0644 ${coolerControlConfig} /etc/coolercontrol/config.toml"
  ];

  environment.systemPackages = with pkgs; [
    lm_sensors
  ];
}
