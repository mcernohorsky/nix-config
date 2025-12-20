{ config, lib, pkgs, ... }:
{
  # Vaultwarden secrets
  age.secrets = {
    vaultwarden-admin-token = {
      file = ../../../secrets/vaultwarden-admin-token.age;
      owner = "vaultwarden";
      group = "vaultwarden";
    };
  };

  # Vaultwarden service
  services.vaultwarden = {
    enable = true;
    environmentFile = config.age.secrets.vaultwarden-admin-token.path;
    config = {
      DOMAIN = "https://oracle-0.tailc41cf5.ts.net";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = true; # Set to false after initial account creation
      WEBSOCKET_ENABLED = true;
    };
  };

  # Caddy reverse proxy with Tailscale HTTPS
  services.caddy.virtualHosts."oracle-0.tailc41cf5.ts.net" = {
    extraConfig = ''
      reverse_proxy localhost:8222

      encode gzip

      header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    '';
  };
}
