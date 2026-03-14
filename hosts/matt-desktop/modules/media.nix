# Media playback configuration
{
  pkgs,
  ...
}:

{
  # Jellyfin Server
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # Audiobookshelf Server
  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    port = 13378;
    openFirewall = false;
  };

  # Media packages
  environment.systemPackages = with pkgs; [
    jellyfin-web
    jellyfin-ffmpeg
    mpv
    ffmpeg-full
  ];

  # Grant Jellyfin access to GPU for hardware transcoding
  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];

  # Bootstrap audiobook library directory on HDD
  systemd.tmpfiles.rules = [
    "d /mnt/hdd/audiobooks 0755 matt users -"
  ];

  # Grant Audiobookshelf read access to the NTFS-mounted HDD (gid=100/users)
  users.users.audiobookshelf.extraGroups = [ "users" ];

  # Ensure Audiobookshelf waits for HDD mount before starting
  systemd.services.audiobookshelf = {
    unitConfig.RequiresMountsFor = [
      "/mnt/hdd"
      "/mnt/hdd/audiobooks"
    ];
  };
}
