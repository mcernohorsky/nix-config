# Vaultwarden, chess and Groundwork backups, every six hours, to Cloudflare
# R2 (pruned here) and to the append-only Restic server on matt-desktop
# (pruned there). Restic backs up a verified SQLite copy, never the live WAL
# files.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sqlite = "${pkgs.sqlite}/bin/sqlite3";

  apps = {
    vaultwarden = {
      dir = "/var/lib/vaultwarden";
      db = "db.sqlite3";
      owner = "vaultwarden:vaultwarden";
      minute = 0;
      prune = [
        "--keep-hourly 24"
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
        "--keep-yearly 2"
      ];
    };
    chess = {
      dir = "/var/lib/containers/repertoire-builder-v2";
      db = "data/repertoire.sqlite3";
      owner = null;
      minute = 15;
      exclude = [ "data/.bun" ];
      prune = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
      ];
    };
    # Groundwork's database must not be opened by a second program, so the
    # server writes its own copy (VACUUM INTO) when asked by `request`;
    # `db` is that copy. Map data is refetchable.
    groundwork = {
      dir = "/var/lib/containers/groundwork";
      db = "state/tenants/main/backup/main.db";
      request = "state/tenants/main/backup-now";
      owner = null;
      minute = 5;
      exclude = [
        "data"
        "state/tenants/dev"
        "state/tenants/main/main.db"
        "state/tenants/main/main.db-wal"
        "state/tenants/main/main.db-shm"
      ];
      prune = [
        "--keep-hourly 24"
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
        "--keep-yearly 2"
      ];
    };
  };

  destinations = {
    r2 = {
      repository = "s3:https://7e3c26c90ada28d96fe960ee130dbebf.r2.cloudflarestorage.com/oracle-0-backups";
      environmentFile = config.age.secrets.restic-r2-credentials.path;
      offset = 0;
      prune = true;
    };
    desktop = {
      repository = "rest:http://matt-desktop.tailc41cf5.ts.net:8000/";
      environmentFile = null;
      offset = 30;
      prune = false;
    };
  };

  mkBackup =
    name: app: dest:
    let
      live = "${app.dir}/${app.db}";
    in
    {
      inherit (dest) repository environmentFile;
      passwordFile = config.age.secrets.restic-password.path;
      initialize = true;
      paths = [ app.dir ];
      exclude = [
        live
        "${live}-shm"
        "${live}-wal"
      ]
      ++ map (path: "${app.dir}/${path}") (app.exclude or [ ]);
      backupPrepareCommand = "systemctl start --wait ${name}-backup-prepare.service";
      pruneOpts = lib.optionals dest.prune (
        app.prune
        ++ [
          "--tag"
          name
        ]
      );
      extraBackupArgs = [
        "--verbose"
        "--tag"
        name
        "--tag"
        "oracle-0"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 00,06,12,18:${lib.fixedWidthNumber 2 (app.minute + dest.offset)}:00";
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };

  # Write a verified copy beside the live DB, failing closed if it is missing.
  mkPrepare = name: app: {
    description = "Prepare ${name} backup (SQLite backup)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      db=${app.dir}/${app.db}
      ${lib.optionalString (app ? request) ''
        # The app deletes the request once its fresh copy is in place.
        request=${app.dir}/${app.request}
        touch "$request"
        for _ in $(seq 120); do
          test -e "$request" || break
          sleep 1
        done
        if test -e "$request"; then
          rm -f "$request"
          echo "${name} did not write a fresh copy" >&2
          exit 1
        fi
      ''}
      test -s "$db"
      tmp=$(mktemp "$(dirname "$db")/.db-backup.sqlite3.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      ${sqlite} "$db" ".backup '$tmp'"
      test "$(${sqlite} "$tmp" 'PRAGMA integrity_check;')" = ok
      ${lib.optionalString (app.owner != null) ''chown ${app.owner} "$tmp"''}
      chmod 0600 "$tmp"
      mv -f "$tmp" "$(dirname "$db")/db-backup.sqlite3"
    '';
  };

  forEach =
    f:
    lib.concatMapAttrs (
      name: app: lib.mapAttrs' (dest: d: lib.nameValuePair "${name}-${dest}" (f name app d)) destinations
    ) apps;
in
{
  age.secrets = {
    restic-password.file = ../../../secrets/restic-password.age;
    restic-r2-credentials.file = ../../../secrets/restic-r2-credentials.age;
  };

  services.restic.backups = forEach mkBackup;

  systemd.services =
    lib.mapAttrs' (name: app: lib.nameValuePair "${name}-backup-prepare" (mkPrepare name app)) apps
    # Retry an unavailable destination instead of waiting six hours.
    //
      lib.mapAttrs'
        (
          name: _:
          lib.nameValuePair "restic-backups-${name}" {
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "15min";
            };
          }
        )
        (
          forEach (
            _: _: _:
            null
          )
        );
}
