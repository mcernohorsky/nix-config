# Hyprland desktop environment with UWSM session management
{ config, lib, pkgs, ... }:

{
  # Enable Hyprland with UWSM for proper systemd integration
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # XDG portal for screen sharing, file dialogs, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Login manager: greetd with tuigreet (launches UWSM session)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%Y-%m-%d %H:%M' --asterisks --asterisks-char '•' --greeting 'matt-desktop' --width 50 --window-padding 2 --container-padding 2 --remember --remember-session --theme 'border=yellow;greet=yellow;time=gray;prompt=green;action=cyan;button=yellow;input=white' --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # Enable polkit for privilege escalation dialogs
  security.polkit.enable = true;

  # Enable GNOME keyring for password storage
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # PAM service for hyprlock (required for authentication)
  security.pam.services.hyprlock = {};

  # Audio via PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Desktop utilities
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wl-clipboard
    cliphist
    wtype

    # Screenshots
    grim
    slurp
    swappy

    # Screen recording
    wf-recorder

    # Notifications (swaync - feature-rich notification center)
    libnotify
    swaynotificationcenter

    # Lock screen and idle
    hyprlock
    hypridle

    # Polkit agent
    polkit_gnome

    # Audio control
    pavucontrol
    pwvucontrol

    # Brightness control
    brightnessctl

    # Network manager applet
    networkmanagerapplet

    # OSD for volume/brightness
    swayosd

    # Color picker
    hyprpicker
  ];

  # Enable dconf for GNOME apps settings
  programs.dconf.enable = true;

  # Fonts - Stylix handles most fonts, adding nerd fonts for icons
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
    ];
  };
}
