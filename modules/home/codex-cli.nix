{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.codexCli;
in
{
  options.modules.home.codexCli.enable = lib.mkEnableOption "Codex CLI";

  config = lib.mkIf cfg.enable {
    # A writable Bun-global install lets T3 Code detect and update the CLI
    # without a Nix rebuild. Keep the login under the user's ~/.codex.
    home.activation.installCodexCli = lib.hm.dag.entryAfter [ "installOpenCodeV2" ] ''
      if [ ! -x "$HOME/.bun/bin/codex" ]; then
        run ${lib.getExe pkgs.bun} install -g @openai/codex
      fi
    '';
  };
}
