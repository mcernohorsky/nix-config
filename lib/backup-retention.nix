# Restic retention for oracle-0's backups, shared by its R2 job and the
# desktop's prune of the append-only repository.
[
  "--keep-hourly 24"
  "--keep-daily 14"
  "--keep-weekly 8"
  "--keep-monthly 12"
  "--keep-yearly 2"
]
