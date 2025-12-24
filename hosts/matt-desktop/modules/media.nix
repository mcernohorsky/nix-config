# Media playback configuration
{ config, lib, pkgs, ... }:

{
  # Jellyfin Server
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # Media packages
  environment.systemPackages = with pkgs; [
    jellyfin-web
    jellyfin-ffmpeg
    mpv
    ffmpeg-full
  ];

  # Grant Jellyfin access to GPU for hardware transcoding
  users.users.jellyfin.extraGroups = [ "video" "render" ];
}
