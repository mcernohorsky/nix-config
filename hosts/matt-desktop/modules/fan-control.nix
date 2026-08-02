{ config, pkgs, ... }:

{
  # The in-tree NCT6683 driver is present on this kernel, but it does not
  # expose this board's Super I/O controller. Use the Nix-packaged NCT6687-R
  # driver and load it at boot so hwmon/PWM discovery is reproducible.
  boot.extraModulePackages = [ config.boot.kernelPackages.nct6687d ];
  boot.kernelModules = [ "nct6687" ];

  # CoolerControl owns runtime fan profiles; physical header mapping and
  # calibration remain deliberately unconfigured until the channels are
  # identified on the running machine.
  programs.coolercontrol.enable = true;

  environment.systemPackages = with pkgs; [
    lm_sensors
    stress-ng
  ];
}
