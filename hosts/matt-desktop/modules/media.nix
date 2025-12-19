# Media playback configuration
{ config, lib, pkgs, ... }:

{
  # Jellyfin Server
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # Hardware acceleration packages
  environment.systemPackages = with pkgs; [
    # Jellyfin server utilities
    jellyfin-web
    jellyfin-ffmpeg

    # MPV media player
    mpv
    vlc

    # Media codecs
    ffmpeg-full
  ];

  # User groups for hardware acceleration
  users.users.jellyfin.extraGroups = [ "video" "render" ];
}
