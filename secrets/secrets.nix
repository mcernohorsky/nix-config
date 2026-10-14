let
  inherit (import ../lib/keys.nix) matt matt-desktop oracle-0;
  workstations = [
    matt
    matt-desktop
  ];
  all = workstations ++ [ oracle-0 ];
in
{
  # Mints tag:trusted nodes, so tag:cloud (Oracle) must never read it.
  "tailscale-authkey.age".publicKeys = workstations;
  "tailscale-oracle-authkey.age".publicKeys = [
    matt
    oracle-0
  ]; # restricted to tag:cloud
  "tailscale-policy-oauth.age".publicKeys = workstations; # policy_file API scope
  "ssh-id-ed25519.age".publicKeys = workstations; # matt's private key for desktop-to-Mac SSH
  "cloudflared-token.age".publicKeys = all;
  "vaultwarden-admin-token.age".publicKeys = all;
  "restic-password.age".publicKeys = all;
  "restic-r2-credentials.age".publicKeys = all;
  "grafana-secret-key.age".publicKeys = all;
}
