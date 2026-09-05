{ pkgs, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  # simpledrm grabs fb0 first and NVIDIA takes over later, causing flicker.
  # Let Plymouth use simpledrm immediately: brief flicker, but Plymouth always works.
  boot.kernelParams = [
    "plymouth.use-simpledrm"
    # Enable enterprise DDC for reliable I2C access on NVIDIA GPUs
    "nvidia.NVreg_RegistryDwords=RMUseEnterpriseDdc=1"
  ];
  boot.plymouth.extraConfig = ''
    DeviceTimeout=0
    ShowDelay=0
  '';
  boot.loader.systemd-boot.consoleMode = "max";

  hardware.graphics.enable = true;

  # Accept the proprietary NVIDIA license alongside the module that requires it.
  nixpkgs.config.nvidia.acceptLicense = true;

  # ddcutil: NVIDIA's DPMS path is unreliable under Wayland.
  hardware.i2c.enable = true;

  boot.kernelModules = [
    "i2c-dev"
    "i2c-nvidia-gpu"
  ];

  hardware.nvidia = {
    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Use proprietary kernel modules (open modules have memory bugs)
    open = false;

    # Enable power management (fixes suspend/resume)
    powerManagement.enable = true;

    # Track NVIDIA's current production branch for stability and regular fixes.
    branch = "production";
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # VA-API support for hardware video acceleration
  environment.systemPackages = with pkgs; [
    nvidia-vaapi-driver
    libva-utils
    vulkan-tools
    mesa-demos
    ddcutil
  ];
}
