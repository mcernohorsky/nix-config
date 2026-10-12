{ lib, pkgs, ... }:
let
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

  configureT3 = pkgs.writeShellApplication {
    name = "configure-t3-muse";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      settings_dir="$HOME/.t3/userdata"
      settings_file="$settings_dir/settings.json"
      # Configure only an already-added Muse instance; T3 owns the rest of
      # this writable file and watches atomic replacements for live refresh.
      if [ ! -f "$settings_file" ] || ! jq -e '.providerInstances.muse.driver == "muse"' "$settings_file" >/dev/null; then
        exit 0
      fi
      settings_temp="$(mktemp "$settings_dir/.settings.json.XXXXXX")"
      trap 'rm -f "$settings_temp"' EXIT
      jq --arg launcher "$HOME/.local/bin/muse-t3-contributor" '
        .providerInstances.muse.config.binaryPath = $launcher |
        if .providerInstances.muse.displayName == null or .providerInstances.muse.displayName == "Muse Code" then
          .providerInstances.muse.displayName = "Muse Code (Contributor)"
        else . end
      ' "$settings_file" >"$settings_temp"
      if ! cmp -s "$settings_temp" "$settings_file"; then
        chmod 0600 "$settings_temp"
        mv -f "$settings_temp" "$settings_file"
      fi
    '';
  };
in
{
  home.file.".local/bin/muse-t3-contributor".source = t3ContributorLauncher;

  home.activation.configureMuseCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe configure}
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
        run ${lib.getExe configureT3}
      '';
}
