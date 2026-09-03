# Desktop services used by COSMIC and graphical applications
{
  inputs,
  pkgs,
  ...
}:

let
  nordwand-mono = pkgs.callPackage ../../../packages/nordwand-mono.nix {
    src = inputs.nordwand-mono;
  };
in
{
  # Enable polkit for privilege escalation dialogs
  security.polkit.enable = true;

  # Enable GNOME keyring for password storage
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.cosmic-greeter.enableGnomeKeyring = true;

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

  # Desktop utilities
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wl-clipboard

    # Screen recording
    wf-recorder

    # Notifications
    libnotify

    # External display brightness
    asdbctl

    # Advanced PipeWire control beyond COSMIC Settings
    pwvucontrol

  ];

  # Enable dconf for GNOME apps settings
  programs.dconf.enable = true;

  # Fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nordwand-mono
      maple-mono.NF-unhinted
      ioskeley-mono.normal
      ioskeley-mono.normal-NF
      ioskeley-mono.normal-term-NF
      jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      open-sans
    ];
    fontconfig.defaultFonts.monospace = [
      "NordwandMono Nerd Font Mono"
    ];
  };
}
