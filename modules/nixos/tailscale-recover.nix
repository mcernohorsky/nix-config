# A deleted control-plane node leaves tailscaled running while it repeatedly
# reports `404: node not found`, so Restart=on-failure cannot help. Check the
# latest relevant event and, only for that state or an explicit login state,
# restart the daemon and reuse nixpkgs' OAuth-aware autoconnect unit.
{ pkgs, ... }:
{
  systemd.services.tailscale-recover = {
    description = "Recover Tailscale machine authorization";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    unitConfig = {
      StartLimitIntervalSec = 3600;
      StartLimitBurst = 3;
    };
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "2min";
    };
    script = ''
      state="$(${pkgs.tailscale}/bin/tailscale status --json --peers=false \
        | ${pkgs.jq}/bin/jq -r '.BackendState' || true)"
      last_relevant="$(${pkgs.systemd}/bin/journalctl -b -u tailscaled.service \
        --no-pager --output=cat --lines=1 \
        --grep='node not found|Switching ipn state .* -> Running' || true)"

      if [[ "$state" != "NeedsLogin" \
        && "$state" != "NeedsMachineAuth" \
        && "$last_relevant" != *"node not found"* ]]; then
        exit 0
      fi

      echo "Tailscale authorization is unhealthy; restarting and re-authenticating"
      ${pkgs.systemd}/bin/systemctl restart tailscaled.service
      ${pkgs.systemd}/bin/systemctl start tailscaled-autoconnect.service
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
}
