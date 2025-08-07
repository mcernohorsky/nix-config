{ config, lib, pkgs, ... }:
{
  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server"; # enable subnet routing if needed later
    openFirewall = true;
  };

  # Fail2ban (protect SSH/Caddy)
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    maxretry = 5;
    jails = {
      sshd.settings.enabled = true;
      # Caddy jail: use packaged filter; read logs via journald (Caddy logs to journal by default on NixOS)
      caddy = {
        enabled = true;
        filter = "caddy";
        settings = {
          backend = "systemd";
          journalmatch = "_SYSTEMD_UNIT=caddy.service";
          maxretry = 10;
          findtime = "10m";
          bantime = "1h";
        };
      };
    };
  };

  # Firewall
  networking.firewall = {
    allowedTCPPorts = [ 22 80 443 ];
    trustedInterfaces = [ "br-containers" ];
  };
}


