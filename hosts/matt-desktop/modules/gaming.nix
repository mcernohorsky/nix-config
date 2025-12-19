# Gaming configuration with Steam, Gamescope, and related tools
{ config, lib, pkgs, ... }:

{
  # Enable Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  # Gamescope compositor for gaming
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # GameMode for performance optimization
  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  # Gaming packages
  environment.systemPackages = with pkgs; [
    # Performance overlay
    mangohud

    # Proton management
    protonup-qt

    # Controller support
    gamepad-tool

    # Wine for non-Steam games
    wineWowPackages.stable
    winetricks

    # Lutris game launcher
    lutris
  ];

  # Gamepad/controller support
  # hardware.xpadneo.enable = true;

  # Enable 32-bit support for Steam
  hardware.graphics.enable32Bit = true;

  # Open firewall for Steam
  networking.firewall = {
    allowedTCPPorts = [ 27036 27037 ];
    allowedUDPPorts = [ 27031 27036 ];
  };
}
