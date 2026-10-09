let
  keys = import ../lib/keys.nix;
  inherit (keys) matt matt-desktop oracle-0;
  all = [
    matt
    matt-desktop
    oracle-0
  ];
  workstations = [
    matt
    matt-desktop
  ];
  oracle = [
    matt
    oracle-0
  ];
in
{
  "tailscale-authkey.age".publicKeys = all;
  "tailscale-oracle-authkey.age".publicKeys = oracle; # restricted to tag:cloud
  "tailscale-policy-oauth.age".publicKeys = workstations; # policy_file API scope
  "ssh-id-ed25519.age".publicKeys = workstations; # matt's private key for desktop-to-Mac SSH
  "cloudflared-token.age".publicKeys = all;
  "vaultwarden-admin-token.age".publicKeys = all;
  "restic-password.age".publicKeys = all;
  "restic-r2-credentials.age".publicKeys = all;
  "grafana-secret-key.age".publicKeys = all;
}
