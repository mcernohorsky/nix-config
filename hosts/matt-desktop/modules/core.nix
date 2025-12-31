# Core system configuration
# Networking, security, locale, and system essentials
{ config, lib, pkgs, ... }:

{
  # ===================
  # Networking
  # ===================
  networking = {
    # Use NetworkManager for easy network management
    networkmanager = {
      enable = true;
      wifi.powersave = false; # Better stability
      ensureProfiles.profiles = {
        # Direct ethernet cable to MacBook - use link-local so it doesn't timeout waiting for DHCP
        direct-ethernet = {
          connection = {
            id = "direct-ethernet";
            type = "ethernet";
            interface-name = "enp4s0";
          };
          ipv4.method = "link-local";
          ipv6.method = "link-local";
        };
      };
    };

    # Firewall
    firewall = {
      enable = true;
      allowPing = true;
      # Default deny, open ports as needed in other modules
    };

    # mDNS/DNS-SD for local network discovery
    # (find printers, chromecast, etc.)
  };

  # Don't wait for network during boot (nothing needs it that early)
  systemd.services.NetworkManager-wait-online.enable = false;

  # Avahi for mDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Resolved for DNS (with mDNS support)
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    fallbackDns = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  # ===================
  # Time and Locale
  # ===================
  time.timeZone = "America/Edmonton";

  i18n = {
    defaultLocale = "en_CA.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_CA.UTF-8";
      LC_IDENTIFICATION = "en_CA.UTF-8";
      LC_MEASUREMENT = "en_CA.UTF-8";
      LC_MONETARY = "en_CA.UTF-8";
      LC_NAME = "en_CA.UTF-8";
      LC_NUMERIC = "en_CA.UTF-8";
      LC_PAPER = "en_CA.UTF-8";
      LC_TELEPHONE = "en_CA.UTF-8";
      LC_TIME = "en_CA.UTF-8";
    };
  };

  # ===================
  # Bootloader & Console
  # ===================
  boot = {
    # Plymouth splash screen for a pretty boot & LUKS prompt
    plymouth = {
      enable = true;
    };

    # Use systemd in initrd (modern and required for TPM2/Plymouth)
    initrd.systemd = {
      enable = true;
      tpm2.enable = true;
    };

    # Silence kernel logs during boot
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
      # Nvidia-specific fixes for Plymouth/LUKS
      "nvidia-drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia_drm.fbdev=1"
    ];
  };

  # HiDPI Console Font
  console = {
    earlySetup = false; # Don't load in initrd to avoid red error
    packages = [ pkgs.terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz"; 
    keyMap = "us";
  };

  # Enable TPM2 support
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # ===================
  # Security
  # ===================

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };

  # rtkit for realtime audio priority
  security.rtkit.enable = true;

  # Enable audit framework (useful for security monitoring)
  security.auditd.enable = false; # Enable if you need it

  # ===================
  # Services
  # ===================

  # D-Bus
  services.dbus.enable = true;

  # UPower for power management info
  services.upower.enable = true;

  # Udisks2 for automounting removable drives
  services.udisks2.enable = true;

  # GVFS for Nautilus to see/mount drives
  services.gvfs.enable = true;

  # Smartd for disk health monitoring
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # fwupd for firmware updates
  services.fwupd.enable = true;

  # Printing (CUPS)
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      hplip
    ];
  };

  # Locate database for fast file search
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
  };

  # Periodic TRIM for SSDs
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # Btrfs scrubbing (you have btrfs from disk-config)
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # ===================
  # Shell
  # ===================
  # Keep bash as login shell for POSIX compatibility
  # Users can manually run 'nu' to enter nushell, or set their terminal to run it
  programs.bash.completion.enable = true;

  environment.systemPackages = with pkgs; [
    # Core utilities
    coreutils
    findutils
    gnugrep
    gnused
    gawk

    # File management
    file
    tree
    unzip
    zip
    p7zip
    xdg-utils

    # Networking tools
    curl
    wget
    dig
    nmap
    inetutils

    # System monitoring
    iotop
    lsof

    # Hardware info
    pciutils
    usbutils
    lshw
    dmidecode

    # Disk utilities
    parted
    gptfdisk
    smartmontools
    ncdu

    # Text editors (fallback)
    nano

    # Version control
    git

    # Process management
    killall
    psmisc

    # Nix tools
    nix-output-monitor
    nvd
    nix-tree
  ];

  # ===================
  # Environment
  # ===================
  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
    BROWSER = "zen";
  };

  # Enable man pages
  documentation = {
    enable = true;
    man.enable = true;
    dev.enable = true;
  };

  # ===================
  # Misc
  # ===================

  # Enable firmware updates and microcode
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # Allow running unpatched dynamic binaries
  programs.nix-ld.enable = true;
}
