# SSH public keys for secret encryption
# Note: Using SSH public keys directly instead of age-converted keys
# because age can decrypt with SSH private keys directly
let
  # User keys (for editing secrets)
  matt-macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP";

  # Host keys (for decryption on target machines)
  matt-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACF1GTzZ7Im6JEByiOPam0BMwJtqMP4ud3ni1pmiNeV";
  oracle-0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfUg/nBbInHvjCLoo0CX0Wvh/VW8TxBOc8ve587ba/Y";

  # Key groups
  allUsers = [ matt-macbook ];
  allHosts = [ matt-desktop oracle-0 ];
  all = allUsers ++ allHosts;
in
{
  # Tailscale OAuth client secret (used as auth key)
  "tailscale-authkey.age".publicKeys = all;

  # Cloudflare Tunnel token for oracle-0
  "cloudflared-token.age".publicKeys = all;

  # Vaultwarden admin token (Argon2 hash)
  "vaultwarden-admin-token.age".publicKeys = all;

  # Restic backup encryption password
  "restic-password.age".publicKeys = all;

  # Cloudflare R2 credentials for restic backups
  "restic-r2-credentials.age".publicKeys = all;
  # Restic REST server htpasswd for matt-desktop
  "restic-rest-server-htpasswd.age".publicKeys = all;
}
