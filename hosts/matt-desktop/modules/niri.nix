{
  config,
  pkgs,
  ...
}:

{
  programs.niri = {
    enable = true;
  };

  security.pam.services.hyprlock = { };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  xdg.portal.configPackages = [ config.programs.niri.package ];

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
