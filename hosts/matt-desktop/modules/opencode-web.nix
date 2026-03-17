{
  config,
  inputs,
  pkgs,
  ...
}:
let
  opencodePkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in
{
  # Secret for HTTP basic auth
  age.secrets.opencode-server-password = {
    file = ../../../secrets/opencode-server-password.age;
    owner = "matt";
    group = "users";
  };

  # Ensure working directory exists
  systemd.tmpfiles.rules = [
    "d /home/matt/Developer 0755 matt users -"
  ];

  # OpenCode web UI service (localhost only)
  systemd.services.opencode-web = {
    description = "OpenCode web UI";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      User = "matt";
      WorkingDirectory = "/home/matt/Developer";
      EnvironmentFile = config.age.secrets.opencode-server-password.path;
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStart = "${opencodePkg}/bin/opencode web --hostname 127.0.0.1 --port 4097";
    };
  };

  # Tailscale Serve configuration for OpenCode web UI
  # Publishes localhost:4097 to the tailnet at https://matt-desktop.tailc41cf5.ts.net
  systemd.services.opencode-web-serve = {
    description = "Configure Tailscale Serve for OpenCode web UI";
    after = [
      "tailscaled.service"
      "opencode-web.service"
    ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    partOf = [ "tailscaled.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      # Wait for Tailscale to be connected
      until ${pkgs.tailscale}/bin/tailscale status --peers=false 2>/dev/null | grep -q "100\."; do
        echo "Waiting for Tailscale to be connected..."
        sleep 2
      done

      # Configure Tailscale Serve to proxy to localhost OpenCode web UI
      # --bg runs in background, funnelfrom is disabled (no public internet exposure)
      echo "Configuring Tailscale Serve for OpenCode web UI..."
      ${pkgs.tailscale}/bin/tailscale serve --bg http://127.0.0.1:4097
    '';
  };
}
