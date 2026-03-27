# Shared desktop services and greetd configuration
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Login manager: greetd with tuigreet
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%Y-%m-%d %H:%M' --asterisks --asterisks-char '•' --width 50 --window-padding 2 --container-padding 2 --remember --remember-session --theme 'border=yellow;greet=yellow;time=gray;prompt=green;action=cyan;button=yellow;input=white' --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
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
  security.pam.services.hyprlock = { };

  # Audio via PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;
      extraConfig."90-studio-display-capture" = {
        "wireplumber.settings" = {
          "node.stream.default-capture-volume" = 1.0;
          "node.stream.restore-props" = false;
        };
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "node.name" = "~alsa_input.usb-Apple_Inc._Studio_Display_.*";
              }
            ];
            actions.update-props = {
              "session.suspend-timeout-seconds" = 0;
              "audio.rate" = 48000;
              "api.alsa.disable-mmap" = true;
              "api.alsa.multi-rate" = false;
              "api.alsa.soft-mixer" = true;
            };
          }
        ];
      };
    };
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

    # Notifications
    libnotify

    # Lock screen
    hyprlock

    # Polkit agent
    polkit_gnome

    # Audio control
    pavucontrol
    pwvucontrol

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
