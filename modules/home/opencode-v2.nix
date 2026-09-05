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
    home = {
      packages = [ pkgs.bun ];
      sessionPath = lib.mkAfter [ "$HOME/.bun/bin" ];
      shellAliases.oc = "opencode2";
    };

    # Nushell does not consume Home Manager's POSIX session-variable script.
    # Set its structured PATH directly so `nu` also works when it is launched
    # without an intermediate Bash or Zsh login shell.
    programs.nushell.extraEnv = lib.mkAfter ''
      let bun_bin_dir = ($nu.home-dir | path join ".bun" "bin")
      $env.PATH = (
        $env.PATH
        | prepend $bun_bin_dir
        | uniq
      )
    '';

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = true;
      # Default to auto-approve shell; ask only for destructive actions.
      # (Build agent defaults already ask for external dirs and .env reads.)
      # Last match wins, so broad allow goes first.
      permissions = [
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "rm -rf *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "sudo rm -rf *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "git push *";
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
