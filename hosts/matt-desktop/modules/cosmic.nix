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

  # The desktop shares its display with the Mac and runs headless at times.
  # cosmic-greeter exits when DRM reports zero outputs; lift the restart burst
  # limit and slow the retry so the login screen appears on its own after
  # monitor hotplug instead of sticking in start-limit-hit. The module's
  # Restart=on-success is kept, so real crashes still fail visibly.
  systemd.services.greetd = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = "10s";
  };

  # COSMIC's Store is pulled in only when Flatpak is enabled.  Keep Flatpak
  # disabled and omit the terminal/wallpaper bundles so those choices remain
  # declarative in Home Manager (Ghostty and our wallpaper source respectively).
  environment.cosmic.excludePackages = with pkgs; [
    cosmic-initial-setup
    cosmic-term
    cosmic-wallpapers
  ];
}
