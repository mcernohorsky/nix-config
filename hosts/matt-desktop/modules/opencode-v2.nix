# OpenCode v2 remote access: expose the normal per-user managed
# background service through Tailscale Serve.
#
# There is deliberately no standalone `opencode serve` unit here. The
# user's own OpenCode clients own the managed service; this module only
# keeps Tailscale Serve pointed at whatever localhost endpoint the
# managed service is currently registered at, and makes sure the managed
# service starts at boot so phone-only access survives reboots.
{ ... }:
{
  systemd.tmpfiles.rules = [
    "d /home/matt/Developer 0755 matt users -"
    "d /home/matt/.local/opt/opencode 0755 matt users -"
    "d /home/matt/.local/state/opencode 0755 matt users -"
  ];

  # The managed service runs in matt's user manager, which needs lingering
  # to exist at boot without an active login.
  users.users.matt.linger = true;

  systemd.user.services.opencode-managed-autostart = {
    description = "Start the OpenCode managed service at boot";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionPathExists = "/home/matt/.bun/bin/opencode";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/home/matt/.bun/bin/opencode service start";
    };
  };

  systemd.services.opencode-tailscale-sync = {
    description = "Point Tailscale Serve at the OpenCode managed service";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "60s";
      Environment = [ "OPENCODE_SERVICE_FILE=/home/matt/.local/state/opencode/service.json" ];
      ExecStart = "/etc/profiles/per-user/matt/bin/opencode-tailscale-sync";
    };
  };

  systemd.paths.opencode-tailscale-sync = {
    description = "Resync Tailscale Serve when OpenCode re-registers";
    wantedBy = [ "multi-user.target" ];

    pathConfig = {
      PathChanged = "/home/matt/.local/state/opencode";
      Unit = "opencode-tailscale-sync.service";
    };
  };

  systemd.timers.opencode-tailscale-sync = {
    description = "Periodically resync Tailscale Serve with OpenCode";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
      Unit = "opencode-tailscale-sync.service";
    };
  };
}
