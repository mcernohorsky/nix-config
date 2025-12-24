# Nvidia GPU configuration for Wayland/Hyprland
# Best practices for 2024/2025 with explicit sync support
{ config, lib, pkgs, ... }:

{
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  hardware.nvidia = {
    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Use proprietary kernel modules (open modules have memory bugs)
    open = false;

    # Enable power management (fixes suspend/resume)
    powerManagement.enable = true;

    # Use production drivers
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Environment variables for Wayland + Nvidia
  environment.sessionVariables = {
    # Force Electron/Chromium apps to use Wayland
    NIXOS_OZONE_WL = "1";
    # Nvidia-specific Wayland settings
    LIBVA_DRIVER_NAME = "nvidia";
    # Hardware video acceleration
    NVD_BACKEND = "direct";
  };

  # VA-API support for hardware video acceleration
  environment.systemPackages = with pkgs; [
    nvidia-vaapi-driver
    libva-utils
    vulkan-tools
    mesa-demos
  ];
}
