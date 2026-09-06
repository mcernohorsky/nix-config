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

  # Chess (repertoire-builder) backup: same shape, distinct tag/path/retention
  # (plan: consistent prepared DB, six-hour cadence, daily 14 / weekly 8 /
  # monthly 12). The live DB lives at
  # /var/lib/containers/repertoire-builder-v2/data/repertoire.sqlite3
  # (host dir mode 0750, DB 0600); we back up the verified atomic copy, not
  # the live WAL files.
  mkChessBackup =
    {
      repository,
      onCalendar,
      environmentFile ? null,
      pruneOpts ? [ ],
    }:
    {
      inherit repository environmentFile pruneOpts;
      passwordFile = config.age.secrets.restic-password.path;

      paths = [
        "/var/lib/containers/repertoire-builder-v2"
      ];

      exclude = [
        # Exclude the live database (we backup the consistent copy)
        "/var/lib/containers/repertoire-builder-v2/data/repertoire.sqlite3"
        "/var/lib/containers/repertoire-builder-v2/data/repertoire.sqlite3-shm"
        "/var/lib/containers/repertoire-builder-v2/data/repertoire.sqlite3-wal"
        # Exclude runtime tool caches if any ever land beside the data
        "/var/lib/containers/repertoire-builder-v2/data/.bun"
      ];

      timerConfig = {
        OnCalendar = onCalendar;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };

      backupPrepareCommand = ''
        systemctl start --wait chess-backup-prepare.service
      '';

      initialize = true;

      extraBackupArgs = [
        "--verbose"
        "--tag"
        "chess"
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

  # Pre-backup service to create a consistent chess DB dump
  systemd.services.chess-backup-prepare = {
    description = "Prepare chess backup (SQLite backup)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      db=/var/lib/containers/repertoire-builder-v2/data/repertoire.sqlite3
      backup=/var/lib/containers/repertoire-builder-v2/data/db-backup.sqlite3

      # Fail closed rather than silently reusing an old backup if the live DB
      # is missing. Write beside the final file, verify it, then replace it.
      test -s "$db"
      tmp=$(mktemp /var/lib/containers/repertoire-builder-v2/data/.db-backup.sqlite3.XXXXXX)
      trap 'rm -f "$tmp"' EXIT

      ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup '$tmp'"
      test "$(${pkgs.sqlite}/bin/sqlite3 "$tmp" 'PRAGMA integrity_check;')" = ok
      chmod 0600 "$tmp"
      mv -f "$tmp" "$backup"
    '';
  };

  systemd.services.restic-backups-chess-r2.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "15min";
  };
  systemd.services.restic-backups-chess-desktop.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "15min";
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
        "--tag"
        "vaultwarden"
      ];
    };

    # Secondary backup to matt-desktop via Restic REST Server.
    # No pruneOpts: the REST server is append-only, pruning happens locally
    # on matt-desktop. Runs offset by 30 minutes from the R2 backup.
    vaultwarden-desktop = mkVaultwardenBackup {
      repository = "rest:http://matt-desktop.tailc41cf5.ts.net:8000/";
      onCalendar = "*-*-* 00,06,12,18:30:00";
    };

    # Chess primary backup to Cloudflare R2 (same bucket, distinct tag/path).
    # Offset by 15 minutes from the vaultwarden R2 run.
    chess-r2 = mkChessBackup {
      repository = "s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups";
      environmentFile = config.age.secrets.restic-r2-credentials.path;
      onCalendar = "*-*-* 00,06,12,18:15:00";

      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
        "--tag"
        "chess"
      ];
    };

    # Chess secondary backup to matt-desktop, offset from the R2 chess run.
    chess-desktop = mkChessBackup {
      repository = "rest:http://matt-desktop.tailc41cf5.ts.net:8000/";
      onCalendar = "*-*-* 00,06,12,18:45:00";
    };
  };
}
