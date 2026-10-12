{ lib, pkgs, ... }:
let
  # Muse owns its writable launcher and versioned binaries so updates do not
  # need a Nix deployment. Home Manager only installs the launcher once.
  bootstrap = pkgs.writeShellApplication {
    name = "bootstrap-muse-code";
    runtimeInputs = [
      pkgs.bash
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      if [ -x "$HOME/.local/bin/muse" ]; then
        exit 0
      fi

      # Home Manager already manages PATH. Keep activation noninteractive;
      # the launcher can retry a failed download or request sign-in on first use.
      if ! curl -fsSL https://dev.meta.ai/install.sh | \
        env MUSE_INSTALL_DIR="$HOME/.local/bin" MUSE_NO_MODIFY_PATH=1 MUSE_LOGIN=0 bash; then
        [ -x "$HOME/.local/bin/muse" ] || exit 1
        echo "Muse launcher installed; run muse to finish downloading and sign in."
      fi
    '';
  };
in
{
  home.activation.installMuseCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe bootstrap}
  '';
}
