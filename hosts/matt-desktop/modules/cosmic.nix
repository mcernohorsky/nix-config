# COSMIC desktop integration.
{
  pkgs,
  ...
}:

{
  services.desktopManager.cosmic = {
    enable = true;
    # This host is configured declaratively; the first-login wizard would only
    # overwrite those settings and can transiently enable the screen reader.
    showExcludedPkgsWarning = false;
    xwayland.enable = true;
  };

  services.displayManager.cosmic-greeter.enable = true;
  services.displayManager.defaultSession = "cosmic";

  # COSMIC's Store is pulled in only when Flatpak is enabled.  Keep Flatpak
  # disabled and omit the terminal/wallpaper bundles so those choices remain
  # declarative in Home Manager (Ghostty and our wallpaper source respectively).
  environment.cosmic.excludePackages = with pkgs; [
    cosmic-initial-setup
    cosmic-term
    cosmic-wallpapers
  ];
}
