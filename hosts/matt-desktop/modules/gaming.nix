# Gaming configuration with Steam, Gamescope, and related tools
{ pkgs, ... }:

let
  cemuX11Launcher = pkgs.writeShellScript "Cemu" ''
    set -euo pipefail

    export GDK_BACKEND=x11
    export SDL_VIDEODRIVER=x11

    settings="''${XDG_CONFIG_HOME:-$HOME/.config}/Cemu/settings.xml"
    if [ -f "$settings" ]; then
      ${pkgs.xmlstarlet}/bin/xmlstarlet ed -L \
        -u "/content/Graphic/api" -v "1" \
        -u "/content/Graphic/VSync" -v "0" \
        "$settings" || true
    fi

    cmd=("${pkgs.cemu}/bin/Cemu")
    if [ "''${CEMU_MANGOHUD:-0}" = "1" ]; then
      cmd=("${pkgs.mangohud}/bin/mangohud" "''${cmd[@]}")
    fi

    exec ${pkgs.gamemode}/bin/gamemoderun "''${cmd[@]}" "$@"
  '';

  cemuX11 = pkgs.runCommand "cemu-x11" { } ''
    mkdir -p "$out"
    cp -rL ${pkgs.cemu}/* "$out/"
    chmod -R u+w "$out"

    install -Dm755 ${cemuX11Launcher} "$out/bin/Cemu"
    ln -sf Cemu "$out/bin/cemu"

    substituteInPlace "$out/share/applications/info.cemu.Cemu.desktop" \
      --replace-fail "Exec=${pkgs.cemu}/bin/Cemu" "Exec=$out/bin/Cemu"
  '';
in
{
  # Lutris pulls openldap into its FHS rootfs. On this host, openldap 2.6.13
  # repeatedly fails test017-syncreplication-refresh while deploying.
  nixpkgs.overlays = [
    (final: prev: {
      openldap = prev.openldap.overrideAttrs (_old: {
        doCheck = false;
      });
    })
  ];

  # Enable Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Gamescope compositor for gaming
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # GameMode for performance optimization
  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  # Gaming packages
  environment.systemPackages = with pkgs; [
    # Wii U emulation. Wrapped to use Xwayland on niri because Cemu's native
    # Wayland Vulkan presentation path caps BotW around 27-28 FPS on this host.
    cemuX11

    # Performance overlay
    mangohud

    # Proton management
    protonup-qt

    # Controller support
    gamepad-tool

    # Wine for non-Steam games
    wineWow64Packages.stable
    winetricks

    # Lutris game launcher
    lutris
  ];

  # Gamepad/controller support
  # hardware.xpadneo.enable = true;

  # Enable 32-bit support for Steam
  hardware.graphics.enable32Bit = true;

  # Open firewall for Steam
  networking.firewall = {
    allowedTCPPorts = [
      27036
      27037
    ];
    allowedUDPPorts = [
      27031
      27036
    ];
  };
}
