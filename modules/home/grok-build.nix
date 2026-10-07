{ lib, pkgs, ... }:
let
  # Grok's updater expects its native ~/.grok layout. Bootstrap it once and
  # leave its binaries, configuration, and credentials writable afterwards.
  bootstrap = pkgs.writeShellApplication {
    name = "bootstrap-grok-build";
    runtimeInputs = [
      pkgs.bash
      pkgs.curl
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gzip
      pkgs.zstd
    ];
    text = ''
      if [ ! -x "$HOME/.grok/bin/grok" ]; then
        # Home Manager owns the shell rc files; the installer must not edit them.
        curl -fsSL https://x.ai/cli/install.sh | SHELL="" GROK_BIN_DIR="$HOME/.grok/bin" bash
      fi

      # Shells and T3's existing service PATH already include this directory.
      # Follow Grok's managed launcher so self-updates keep working.
      install -d "$HOME/.local/bin"
      ln -sfn "$HOME/.grok/bin/grok" "$HOME/.local/bin/grok"
    '';
  };
in
{
  home.activation.installGrokBuild = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe bootstrap}
  '';
}
