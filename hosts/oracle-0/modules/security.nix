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
      caddy = {
        enabled = true;
        filter = "caddy"; # packaged filter covers common 4xx abuse
        logpath = "/var/log/caddy/access.log";
        settings = {
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


