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

  configure = pkgs.writeShellApplication {
    name = "configure-muse-code";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      settings_dir="$HOME/.config/muse"
      settings_file="$settings_dir/settings.json"
      install -d -m 0700 "$settings_dir"
      settings_temp="$(mktemp "$settings_dir/.settings.json.XXXXXX")"
      trap 'rm -f "$settings_temp"' EXIT

      # Keep subscriber Contributor mode enabled for its higher usage limits.
      # Merge only this preference so Muse can still save other settings.
      if [ -e "$settings_file" ]; then
        jq -e 'type == "object"' "$settings_file" >/dev/null
        jq '.contributor_mode_enabled = true' "$settings_file" >"$settings_temp"
      else
        printf '%s\n' '{"schema_version":1,"contributor_mode_enabled":true}' >"$settings_temp"
      fi
      if ! cmp -s "$settings_temp" "$settings_file"; then
        chmod 0600 "$settings_temp"
        mv -f "$settings_temp" "$settings_file"
      fi
    '';
  };
in
{
  home.activation.configureMuseCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe configure}
  '';
  home.activation.installMuseCode = lib.hm.dag.entryAfter [ "configureMuseCode" ] ''
    run ${lib.getExe bootstrap}
  '';
}
