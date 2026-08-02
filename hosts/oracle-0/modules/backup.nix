{ config, pkgs, ... }:
{
  # Backup secrets
  age.secrets = {
    restic-password = {
      file = ../../../secrets/restic-password.age;
      owner = "root";
      group = "root";
    };

    restic-r2-credentials = {
      file = ../../../secrets/restic-r2-credentials.age;
      owner = "root";
      group = "root";
    };
  };

  # Pre-backup service to create consistent SQLite dump
  systemd.services.vaultwarden-backup-prepare = {
    description = "Prepare Vaultwarden backup (SQLite backup)";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
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

  # Restic backup configuration
  services.restic.backups = {
    # Primary backup to Cloudflare R2
    vaultwarden-r2 = {
      repository = "s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups";
      environmentFile = config.age.secrets.restic-r2-credentials.path;
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

      # Run every 6 hours
      timerConfig = {
        OnCalendar = "*-*-* 00,06,12,18:00:00";
        Persistent = true;
        RandomizedDelaySec = "5min";
      };

      # Prepare SQLite backup before running restic
      backupPrepareCommand = ''
        systemctl start --wait vaultwarden-backup-prepare.service
      '';

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

      # Initialize repository if it doesn't exist
      initialize = true;

      # Extra options for S3 compatibility
      extraBackupArgs = [
        "--verbose"
        "--tag"
        "vaultwarden"
        "--tag"
        "oracle-0"
      ];
    };

    # Secondary backup to matt-desktop via Restic REST Server
    vaultwarden-desktop = {
      repository = "rest:http://matt-desktop.tailc41cf5.ts.net:8000/";
      passwordFile = config.age.secrets.restic-password.path;

      paths = [
        "/var/lib/vaultwarden"
      ];

      exclude = [
        "/var/lib/vaultwarden/db.sqlite3"
        "/var/lib/vaultwarden/db.sqlite3-shm"
        "/var/lib/vaultwarden/db.sqlite3-wal"
      ];

      # Run every 6 hours, offset by 30 minutes from R2 backup
      timerConfig = {
        OnCalendar = "*-*-* 00,06,12,18:30:00";
        Persistent = true;
        RandomizedDelaySec = "5min";
      };

      backupPrepareCommand = ''
        systemctl start --wait vaultwarden-backup-prepare.service
      '';

      # No pruneOpts - matt-desktop REST server is append-only
      # Pruning is handled locally on matt-desktop

      initialize = true;

      extraBackupArgs = [
        "--verbose"
        "--tag"
        "vaultwarden"
        "--tag"
        "oracle-0"
      ];
    };
  };
}
