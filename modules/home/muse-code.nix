{
  config,
  lib,
  pkgs,
  ...
}:
let
  mergeJson = lib.getExe (import ../../lib/merge-json.nix { inherit pkgs; });
  launcher = ".local/bin/muse-t3-contributor";

  t3ContributorLauncher = pkgs.writeShellScript "muse-t3-contributor" ''
    # Muse 1.4.6 serve ignores the saved Contributor preference in some clients:
    # https://github.com/meta-models/muse-code-sdk/issues/102
    # Keep the official writable launcher in charge of binaries and updates.
    if [ "''${1-}" = serve ]; then
      shift
      exec "$HOME/.local/bin/muse" serve "$@" --contributor-mode on
    fi
    exec "$HOME/.local/bin/muse" "$@"
  '';

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
  home.file.${launcher}.source = t3ContributorLauncher;

  # Keep subscriber Contributor mode enabled for its higher usage limits.
  home.activation.configureMuseCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${mergeJson} "$HOME/.config/muse/settings.json" \
      '.schema_version //= 1 | .contributor_mode_enabled = true'
  '';
  home.activation.installMuseCode = lib.hm.dag.entryAfter [ "configureMuseCode" ] ''
    run ${lib.getExe bootstrap}
  '';
  home.activation.configureT3Muse =
    lib.hm.dag.entryAfter
      [
        "installMuseCode"
        "installT3CodeService"
      ]
      ''
        # Configure only an already-added Muse instance; T3 owns the rest.
        run ${mergeJson} "$HOME/.t3/userdata/settings.json" ${lib.escapeShellArg ''
          if .providerInstances.muse.driver == "muse"
          then .providerInstances.muse.config.binaryPath = "${config.home.homeDirectory}/${launcher}"
          end
        ''}
      '';
}
