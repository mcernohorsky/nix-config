{
  config,
  pkgs,
  ...
}:
let
  mkVaultwardenBackup =
    {
      repository,
      onCalendar,
      environmentFile ? null,
      pruneOpts ? [ ],
    }:
    {
      # environmentFile is nullOr with a null default upstream, so passing
      # null through is identical to omitting the attribute.
      inherit repository environmentFile pruneOpts;
      passwordFile = config.age.secrets.restic-password.path;

      paths = [
        "/var/lib/vaultwarden"
      ];

      exclude = [
        # Exclude the live database (we backup the consistent copy)
        "/var/lib/vaultwarden/db.sqlite3"
        "/var/lib/vaultwarden/db.sqlite3-shm"
        "/var/lib/vaultwarden/db.sqlite3-wal"
      ];

      timerConfig = {
        OnCalendar = onCalendar;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };

      # Prepare SQLite backup before running restic
      backupPrepareCommand = ''
        systemctl start --wait vaultwarden-backup-prepare.service
      '';

      initialize = true;

      extraBackupArgs = [
        "--verbose"
        "--tag"
        "vaultwarden"
        "--tag"
        "oracle-0"
      ];
    };
in
{
  # Backup secrets (restic runs as root, so agenix defaults suffice).
  age.secrets = {
    restic-password.file = ../../../secrets/restic-password.age;
    restic-r2-credentials.file = ../../../secrets/restic-r2-credentials.age;
  };

  # Pre-backup service to create consistent SQLite dump
  systemd.services.vaultwarden-backup-prepare = {
    description = "Prepare Vaultwarden backup (SQLite backup)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      db=/var/lib/vaultwarden/db.sqlite3
      backup=/var/lib/vaultwarden/db-backup.sqlite3

      # Fail closed rather than silently reusing an old backup if the live DB
      # is missing. Write beside the final file, verify it, then replace it.
      test -s "$db"
      tmp=$(mktemp /var/lib/vaultwarden/.db-backup.sqlite3.XXXXXX)
      trap 'rm -f "$tmp"' EXIT

      ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup '$tmp'"
      test "$(${pkgs.sqlite}/bin/sqlite3 "$tmp" 'PRAGMA integrity_check;')" = ok
      chown vaultwarden:vaultwarden "$tmp"
      chmod 0600 "$tmp"
      mv -f "$tmp" "$backup"
    '';
  };

  # The calendar timers provide the normal six-hour cadence. If either remote
  # destination is temporarily unavailable, retry that pipeline independently
  # instead of waiting for the next scheduled run.
  systemd.services.restic-backups-vaultwarden-r2.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "15min";
  };
  systemd.services.restic-backups-vaultwarden-desktop.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "15min";
  };

  # Restic backup configuration
  services.restic.backups = {
    # Primary backup to Cloudflare R2
    vaultwarden-r2 = mkVaultwardenBackup {
      repository = "s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups";
      environmentFile = config.age.secrets.restic-r2-credentials.path;
      onCalendar = "*-*-* 00,06,12,18:00:00";

      # Cleanup old backups (GFS retention policy)
      # hourly: 6 days of granular recovery (24 × 6hr intervals)
      # daily: 2 weeks, weekly: 2 months, monthly: 1 year, yearly: 2 years
      pruneOpts = [
        "--keep-hourly 24"
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
        "--keep-yearly 2"
      ];
    };

    # Secondary backup to matt-desktop via Restic REST Server.
    # No pruneOpts: the REST server is append-only, pruning happens locally
    # on matt-desktop. Runs offset by 30 minutes from the R2 backup.
    vaultwarden-desktop = mkVaultwardenBackup {
      repository = "rest:http://matt-desktop.tailc41cf5.ts.net:8000/";
      onCalendar = "*-*-* 00,06,12,18:30:00";
    };
  };
}
