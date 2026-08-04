{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.opencodeV2;
in
{
  options.modules.home.opencodeV2.enable = lib.mkEnableOption "OpenCode v2 beta";

  config = lib.mkIf cfg.enable {
    # OpenCode v2's supported beta installer is Bun. Keep the application in
    # Bun's writable user prefix so its fast-moving beta updater can work.
    home.packages = [ pkgs.bun ];
    home.sessionPath = lib.mkAfter [ "$HOME/.bun/bin" ];

    home.shellAliases.oc = "opencode2";

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = true;
      # V2 has blanket --auto approval, not a reviewer agent. Keep shell
      # actions explicit until OpenCode ships an actual auto-reviewer.
      permissions = [
        {
          action = "shell";
          resource = "*";
          effect = "ask";
        }
      ];
    };

    # Bootstrap a fresh machine, then let OpenCode maintain its own beta
    # binary. Normal Home Manager activations do not reinstall it.
    home.activation.installOpenCodeV2 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.bun/bin/opencode2" ]; then
        run ${lib.getExe pkgs.bun} install -g --trust @opencode-ai/cli@next
      fi
    '';
  };
}
