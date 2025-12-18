{ config, lib, pkgs, ... }:
{
  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server"; # enable subnet routing if needed later
    openFirewall = true;
  };

  # Firewall - all ports closed; access via Tailscale (SSH) and Cloudflare Tunnel (HTTP)
  networking.firewall = {
    allowedTCPPorts = [ ]; # No public ports; Cloudflare Tunnel handles HTTP traffic
    trustedInterfaces = [ "tailscale0" "br-containers" ];
  };

  # Secrets
  age.secrets.cloudflared-token = {
    file = ../../../secrets/cloudflared-token.age;
    mode = "0400";
    owner = "cloudflared";
    group = "cloudflared";
  };

  # Cloudflare Tunnel user/group
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };
  users.groups.cloudflared = {};

  # Cloudflare Tunnel for HTTP access (dashboard-managed with token)
  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file ${config.age.secrets.cloudflared-token.path}";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };
}


