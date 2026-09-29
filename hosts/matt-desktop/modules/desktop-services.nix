# Desktop services used by COSMIC and graphical applications
{ pkgs, ... }:
let
  mono = import ../../../lib/mono-font.nix { inherit pkgs; };
in
{
  security.polkit.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.cosmic-greeter.enableGnomeKeyring = true;

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

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    wf-recorder
    libnotify
    asdbctl
    # Advanced PipeWire control beyond COSMIC Settings.
    pwvucontrol
  ];

  programs.dconf.enable = true;

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nordwand-mono
      maple-mono.NF-unhinted
      ioskeley-mono.standard
      mono.package
      mono.term.package
      jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      open-sans
    ];
    fontconfig.defaultFonts.monospace = [ mono.family ];
  };
}
