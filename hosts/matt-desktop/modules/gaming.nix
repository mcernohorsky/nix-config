{ lib, pkgs, ... }:

let
  # Cemu rewrites settings.xml at runtime, so enforce these at every launch.
  # Seeded values only fill in a fresh file.
  cemuSeed = {
    console_language = "1";
    play_boot_sound = "false";
    "Graphic/GX2DrawdoneSync" = "true";
    "Graphic/UpscaleFilter" = "1";
    "Graphic/DownscaleFilter" = "0";
    "Graphic/FullscreenScaling" = "0";
    "Graphic/vkAccurateBarriers" = "true";
    "Audio/delay" = "2";
    "Audio/TVChannels" = "1";
    "Audio/PadChannels" = "1";
    "Audio/TVDevice" = "default";
    "Audio/PadDevice" = "default";
  };
  cemuSettings = {
    disable_screensaver = "true";
    feral_gamemode = "true";
    check_update = "false";
    receive_untested_updates = "false";
    "Graphic/api" = "1";
    "Graphic/VSync" = "0";
    "Graphic/AsyncCompile" = "true";
    "Audio/api" = "3";
    "Audio/TVVolume" = "100";
    "Audio/PadVolume" = "100";
  };
  setAll = lib.concatMapAttrsStringSep "\n" (path: value: "set_value /content/${path} ${value}");

  cemuX11Launcher = pkgs.writeShellApplication {
    name = "Cemu";
    runtimeInputs = [ pkgs.xmlstarlet ];
    text = ''
      # Cemu's native Wayland Vulkan presentation caps BotW at ~28 FPS.
      export GDK_BACKEND=x11 SDL_VIDEODRIVER=x11

      config="''${XDG_CONFIG_HOME:-$HOME/.config}/Cemu"
      settings="$config/settings.xml"
      games="$HOME/Games/WiiU"
      mkdir -p "$config" "$games/games" "$games/installers/updates" "$games/installers/dlc"

      # Set an element's text, creating it (and its parent) if missing.
      set_value() {
        local parent
        parent="$(dirname "$1")"
        if [ "$(xmlstarlet sel -t -v "count($parent)" "$settings")" = 0 ]; then
          xmlstarlet ed -L -s "$(dirname "$parent")" -t elem -n "$(basename "$parent")" "$settings"
        fi
        if [ "$(xmlstarlet sel -t -v "count($1)" "$settings")" = 0 ]; then
          xmlstarlet ed -L -s "$parent" -t elem -n "$(basename "$1")" "$settings"
        fi
        xmlstarlet ed -L -u "$1" -v "$2" "$settings"
      }

      if [ -s "$settings" ] && ! xmlstarlet sel -t -v 'count(/content)' "$settings" 2>/dev/null | grep -qx 1; then
        echo "Cemu settings.xml is malformed; moving it to settings.xml.invalid" >&2
        mv -f "$settings" "$settings.invalid"
      fi
      if [ ! -s "$settings" ]; then
        echo '<?xml version="1.0" encoding="UTF-8"?><content/>' > "$settings"
        ${setAll cemuSeed}
      fi
      ${setAll cemuSettings}
      if [ "$(xmlstarlet sel -t -v "count(/content/GamePaths)" "$settings")" = 0 ]; then
        xmlstarlet ed -L -s /content -t elem -n GamePaths "$settings"
      fi
      if [ "$(xmlstarlet sel -t -v "count(/content/GamePaths/Entry[text()='$games/games'])" "$settings")" = 0 ]; then
        xmlstarlet ed -L -s /content/GamePaths -t elem -n Entry -v "$games/games" "$settings"
      fi

      cmd=(${pkgs.cemu}/bin/Cemu)
      if [ "''${CEMU_MANGOHUD:-0}" = 1 ]; then
        cmd=(${pkgs.mangohud}/bin/mangohud "''${cmd[@]}")
      fi
      exec ${pkgs.gamemode}/bin/gamemoderun "''${cmd[@]}" "$@"
    '';
  };

  cemuX11 = pkgs.symlinkJoin {
    name = "cemu-x11";
    paths = [ pkgs.cemu ];
    postBuild = ''
      rm -f "$out/bin/Cemu" "$out/bin/cemu"
      ln -s ${lib.getExe cemuX11Launcher} "$out/bin/Cemu"
      ln -s Cemu "$out/bin/cemu"

      # symlinkJoin materializes directories and symlinks only files, so
      # replace the whole dir before patching the Exec line.
      rm -rf "$out/share/applications"
      mkdir -p "$out/share/applications"
      cp "${pkgs.cemu}/share/applications/"*.desktop "$out/share/applications/"
      substituteInPlace "$out/share/applications/info.cemu.Cemu.desktop" \
        --replace-fail "Exec=${pkgs.cemu}/bin/Cemu" "Exec=$out/bin/Cemu"
    '';
  };
in
{
  # Lutris pulls openldap into its FHS rootfs. On this host, openldap 2.6.13
  # repeatedly fails test017-syncreplication-refresh while deploying.
  nixpkgs.overlays = [
    (_final: prev: {
      openldap = prev.openldap.overrideAttrs (_old: {
        doCheck = false;
      });
    })
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  environment.systemPackages = with pkgs; [
    cemuX11

    mangohud
    protonup-qt
    gamepad-tool
    wineWow64Packages.stable
    winetricks
    lutris
  ];

  hardware.graphics.enable32Bit = true;
}
