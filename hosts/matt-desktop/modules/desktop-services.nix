# Desktop services used by COSMIC and graphical applications
{ pkgs, ... }:
let
  mono = import ../../../lib/mono-font.nix { inherit pkgs; };
in
{
  # COSMIC enables the keyring, but only for the `login` PAM service.
  security.pam.services.cosmic-greeter.enableGnomeKeyring = true;

  services.pipewire = {
    alsa.support32Bit = true;
    wireplumber = {
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

  environment.systemPackages = with pkgs; [
    wl-clipboard
    wf-recorder
    libnotify
    asdbctl
    # Advanced PipeWire control beyond COSMIC Settings.
    pwvucontrol
  ];

  fonts = {
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
