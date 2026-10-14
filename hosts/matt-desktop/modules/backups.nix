{ config, ... }:
let
  repo = "/backups/oracle-0/vaultwarden";
in
{
  age.secrets.restic-password = {
    file = ../../../secrets/restic-password.age;
    owner = "restic";
  };

  # Append-only receiver for oracle-0's backups. Tailscale ACLs admit only
  # tag:cloud on this port, so the server needs no auth of its own.
  services.restic.server = {
    enable = true;
    dataDir = repo;
    appendOnly = true;
    extraFlags = [ "--no-auth" ];
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8000 ];

  systemd.tmpfiles.rules = [
    "d /backups 0755 matt users -"
    "d /backups/oracle-0 0755 matt users -"
    "d ${repo} 0755 restic restic -"
  ];

  # oracle-0 can only append, so prune here.
  services.restic.backups.oracle-0-local-prune = {
    repository = repo;
    passwordFile = config.age.secrets.restic-password.path;
    user = "restic";
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    pruneOpts = import ../../../lib/backup-retention.nix;
    checkOpts = [ "--with-cache" ];
  };

  # Daily /home snapshots at /btr_pool/@snapshots/@home.<date>.
  services.btrbk.instances.home = {
    onCalendar = "daily";
    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = "7d 4w";
      volume."/btr_pool".subvolume."@home".snapshot_dir = "@snapshots";
    };
  };
  fileSystems."/btr_pool" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [
      "subvolid=5"
      "noatime"
    ];
  };
}
