# A writable Bun-global install lets T3 Code detect and update the CLI.
{ lib, pkgs, ... }:
{
  home.activation.installCodexCli = lib.hm.dag.entryAfter [ "installOpenCode" ] ''
    if [ ! -x "$HOME/.bun/bin/codex" ]; then
      run ${lib.getExe pkgs.bun} install -g @openai/codex
    fi
  '';
}
