{ pkgs, ... }:

{
  programs.niri.enable = true;

  # Niri 26.04 starts xwayland-satellite on demand when it is available on PATH.
  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
