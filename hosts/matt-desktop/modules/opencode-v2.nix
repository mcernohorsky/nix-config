{
  config,
  pkgs,
  ...
}:
let
  opencodeServer = pkgs.writeShellScript "opencode-v2-server" ''
    set -euo pipefail

    if [ -n "''${OPENCODE_SERVER_PASSWORD:-}" ]; then
      export OPENCODE_PASSWORD="$OPENCODE_SERVER_PASSWORD"
    fi

    exec /home/matt/.bun/bin/opencode2 serve \
      --hostname 127.0.0.1 \
      --port 4097
  '';
in
{
  age.secrets.opencode-server-password = {
    file = ../../../secrets/opencode-server-password.age;
    owner = "matt";
    group = "users";
  };

  systemd.tmpfiles.rules = [
    "d /home/matt/Developer 0755 matt users -"
    "d /home/matt/.local/opt/opencode-beta 0755 matt users -"
  ];

  systemd.services.opencode-v2 = {
    description = "OpenCode v2 beta API server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      User = "matt";
      Group = "users";
      WorkingDirectory = "/home/matt/Developer";
      EnvironmentFile = config.age.secrets.opencode-server-password.path;
      Environment = [ "HOME=/home/matt" ];
      ExecStart = opencodeServer;
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  systemd.services.opencode-v2-serve = {
    description = "Publish OpenCode v2 through Tailscale Serve";
    wantedBy = [ "multi-user.target" ];
    after = [
      "tailscaled.service"
      "opencode-v2.service"
    ];
    requires = [ "tailscaled.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "30s";
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg http://127.0.0.1:4097";
    };
  };
}
