{
  lib,
  pkgs,
  ...
}:

{
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

    # Default deny; ports are opened as needed in other modules.
    firewall.enable = true;
  };

  # Nothing needs the network that early; don't delay boot on it.
  systemd.services.NetworkManager-wait-online.enable = false;

  services.resolved = {
    enable = true;
    settings.Resolve.DNSSEC = "allow-downgrade";
    settings.Resolve.FallbackDNS = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  time.timeZone = "America/Edmonton";

  i18n = {
    defaultLocale = "en_CA.UTF-8";
    extraLocaleSettings = lib.genAttrs [
      "LC_ADDRESS"
      "LC_IDENTIFICATION"
      "LC_MEASUREMENT"
      "LC_MONETARY"
      "LC_NAME"
      "LC_NUMERIC"
      "LC_PAPER"
      "LC_TELEPHONE"
      "LC_TIME"
    ] (_: "en_CA.UTF-8");
  };

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
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
      "amd_pstate=guided"
    ];
  };

  # HiDPI Console Font
  console = {
    earlySetup = false; # Don't load in initrd to avoid red error
    # Leave default console font; custom terminus font caused early boot vconsole failures.
    packages = [ ];
    font = null;
    keyMap = "us";
  };

  # Enable TPM2 support
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  security.rtkit.enable = true;

  services.dbus = {
    enable = true;
    implementation = "broker";
  };

  services.upower.enable = true;
  services.udisks2.enable = true;

  # GIO mounts, trash, and network locations for COSMIC Files and GTK apps.
  services.gvfs.enable = true;

  services.smartd = {
    enable = true;
    autodetect = true;
  };

  services.fwupd.enable = true;

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      # hplip's Qt GUI (pyqt5, EOL, broken with sip>=6.16) is unneeded for CUPS PPDs/filters.
      (hplip.override { withQt5 = false; })
    ];
  };

  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
  };

  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Bash stays the login shell for POSIX compatibility; terminals run nushell.
  programs.bash.completion.enable = true;

  # uv places its user-managed Python executables here. Configure this at the
  # system level as well as in Home Manager so SSH and other login shells see it.
  environment.localBinInPath = true;

  environment.systemPackages = with pkgs; [
    file
    tree
    unzip
    zip
    p7zip
    xdg-utils

    wget
    dig
    nmap
    inetutils

    iotop
    lsof

    pciutils
    usbutils
    lshw
    dmidecode

    parted
    gptfdisk
    smartmontools
    ncdu

    nano
    git

    killall
    psmisc

    nix-output-monitor
    nvd
    nix-tree
  ];

  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
    BROWSER = "helium";
  };

  documentation = {
    enable = true;
    man.enable = true;
    dev.enable = true;
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # This is a plugged-in desktop. Keep CPU policy latency-oriented and ensure
  # boost is enabled under amd-pstate guided mode.
  powerManagement.cpuFreqGovernor = "performance";

  systemd.services.enable-cpu-boost = {
    description = "Enable CPU boost";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      boost=/sys/devices/system/cpu/cpufreq/boost
      if [ -w "$boost" ]; then
        echo 1 > "$boost"
      fi
    '';
  };

  # Allow running unpatched dynamic binaries
  programs.nix-ld.enable = true;
}
