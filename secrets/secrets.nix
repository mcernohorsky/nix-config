# SSH public keys for secret encryption
# Note: Using SSH public keys directly instead of age-converted keys
# because age can decrypt with SSH private keys directly
let
  # User keys (for editing secrets)
  macbook-pro-m2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP";

  # Host keys (for decryption on target machines)
  matt-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACF1GTzZ7Im6JEByiOPam0BMwJtqMP4ud3ni1pmiNeV";
  oracle-0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfUg/nBbInHvjCLoo0CX0Wvh/VW8TxBOc8ve587ba/Y";

  # Key groups
  allUsers = [ macbook-pro-m2 ];
  allHosts = [
    matt-desktop
    oracle-0
  ];
  all = allUsers ++ allHosts;
in
{
  # Tailscale OAuth client secret (used as auth key)
  "tailscale-authkey.age".publicKeys = all;

  # Oracle-only Tailscale OAuth client secret, restricted to tag:cloud.
  "tailscale-oracle-authkey.age".publicKeys = [
    macbook-pro-m2
    oracle-0
  ];

  # Tailscale API OAuth client (policy_file scope only) for programmatic
  # ACL management. Decryptable on the agent hosts only — never Oracle.
  "tailscale-policy-oauth.age".publicKeys = [
    macbook-pro-m2
    matt-desktop
  ];

  # matt's personal SSH private key: the desktop's client identity for
  # Mac-bound SSH (the Mac authorizes its public half via nix-darwin).
  # Same recipients as above — Oracle never sees it.
  "ssh-id-ed25519.age".publicKeys = [
    macbook-pro-m2
    matt-desktop
  ];

  # Cloudflare Tunnel token for oracle-0
  "cloudflared-token.age".publicKeys = all;

  # Vaultwarden admin token (Argon2 hash)
  "vaultwarden-admin-token.age".publicKeys = all;

  # Restic backup encryption password
  "restic-password.age".publicKeys = all;

  # Cloudflare R2 credentials for restic backups
  "restic-r2-credentials.age".publicKeys = all;

  # Better Auth secret for repertoire-builder (oracle-0 only)
  "repertoire-auth.age".publicKeys = [
    macbook-pro-m2
    oracle-0
  ];

  # OpenCode v2 API password shared by the desktop server and remote Mac client
  "opencode-server-password.age".publicKeys = all;

  # Grafana secret key for oracle-0 (NixOS 26.05 requires explicit value)
  "grafana-secret-key.age".publicKeys = all;
}
