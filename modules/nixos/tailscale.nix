# Tailscale is the only management path to the NixOS hosts.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tailscale;
  tailscale = "${cfg.package}/bin/tailscale";
in
{
  options.services.taildrive.shares = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Taildrive shares, mapping share name to path.";
  };

  config = {
    services.tailscale = {
      enable = true;
      openFirewall = true; # UDP 41641 for direct connections
      # The auth keys are OAuth client secrets, whose nodes default to
      # ephemeral; these persistent hosts must survive extended downtime.
      authKeyParameters = {
        ephemeral = false;
        preauthorized = true;
      };
      extraUpFlags = [ "--ssh" ];
    };

    # Never restart during activation, and retry failures indefinitely instead
    # of exhausting systemd's default five-start burst.
    systemd.services.tailscaled = {
      restartIfChanged = false;
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig.RestartSec = lib.mkForce "5s";
    };

    # Access via http://100.100.100.100:8080/<tailnet>/<host>/<share>
    systemd.services.taildrive-shares = lib.mkIf (config.services.taildrive.shares != { }) {
      description = "Configure Taildrive shares";
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "30s";
        ExecStart = lib.mapAttrsToList (
          name: path: "${tailscale} drive share ${name} ${path}"
        ) config.services.taildrive.shares;
      };
    };

    # A deleted control-plane node leaves tailscaled running while it reports
    # `404: node not found`, so Restart=on-failure cannot help. For that state
    # or an explicit login state, restart the daemon and reuse nixpkgs'
    # OAuth-aware autoconnect unit.
    systemd.services.tailscale-recover = {
      description = "Recover Tailscale machine authorization";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "2min";
      };
      path = [
        pkgs.jq
        config.systemd.package
      ];
      script = ''
        state="$(${tailscale} status --json --peers=false | jq -r '.BackendState' || true)"
        last_relevant="$(journalctl -b -u tailscaled.service --no-pager --output=cat --lines=1 \
          --grep='node not found|Switching ipn state .* -> Running' || true)"

        if [[ "$state" != NeedsLogin && "$state" != NeedsMachineAuth \
          && "$last_relevant" != *"node not found"* ]]; then
          exit 0
        fi

        echo "Tailscale authorization is unhealthy; restarting and re-authenticating"
        systemctl restart tailscaled.service
        systemctl start tailscaled-autoconnect.service
      '';
    };

    systemd.timers.tailscale-recover = {
      description = "Periodically verify Tailscale machine authorization";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
        RandomizedDelaySec = "30s";
      };
    };
  };
}
