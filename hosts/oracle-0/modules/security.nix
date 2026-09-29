{ config, pkgs, ... }:
{
  # All public ports are closed; ingress is Tailscale and the outbound tunnel.
  networking.firewall.trustedInterfaces = [
    "tailscale0"
    "br-containers"
  ];

  age.secrets.cloudflared-token = {
    file = ../../../secrets/cloudflared-token.age;
    owner = "cloudflared";
  };

  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };
  users.groups.cloudflared = { };

  # Dashboard-managed tunnel, authenticated by token.
  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file ${config.age.secrets.cloudflared-token.path}";
      Restart = "always";
      RestartSec = "5s";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };
}
