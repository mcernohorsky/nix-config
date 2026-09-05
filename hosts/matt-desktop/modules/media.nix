{
  pkgs,
  ...
}:

{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    port = 13378;
  };

  # Services bundle their own assets; this is just the CLI toolkit.
  environment.systemPackages = with pkgs; [
    ffmpeg-full
  ];

  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];

  systemd.tmpfiles.rules = [
    "d /mnt/hdd/audiobooks 0755 matt users -"
  ];

  # Read access to the NTFS-mounted HDD (mounted with gid=100/users).
  users.users.audiobookshelf.extraGroups = [ "users" ];

  systemd.services.audiobookshelf = {
    unitConfig.RequiresMountsFor = [ "/mnt/hdd" ];
  };
}
