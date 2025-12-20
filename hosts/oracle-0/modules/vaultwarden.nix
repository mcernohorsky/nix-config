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
      DOMAIN = "https://vault.cernohorsky.ca";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      WEBSOCKET_ENABLED = true;
    };
  };

  # Caddy reverse proxy for Vaultwarden
  # Accessed via Cloudflare Tunnel (vault.cernohorsky.ca -> localhost:8222)
  services.caddy.virtualHosts."http://vault.cernohorsky.ca" = {
    listenAddresses = [ "127.0.0.1" ];
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
