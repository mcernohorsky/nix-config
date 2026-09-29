{ lib, pkgs, ... }:

{
  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = false; # Better stability
      # Direct ethernet cable to the MacBook: link-local, so no DHCP timeout.
      ensureProfiles.profiles.direct-ethernet = {
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

  i18n = {
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
    plymouth.enable = true;
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

  # Custom console fonts caused early-boot vconsole failures.
  console.earlySetup = false;

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  security.rtkit.enable = true;

  services.dbus.implementation = "broker";

  services.upower.enable = true;
  services.udisks2.enable = true;

  # GIO mounts, trash, and network locations for COSMIC Files and GTK apps.
  services.gvfs.enable = true;

  services.smartd.enable = true;

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

  services.fstrim.enable = true;

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

  documentation.dev.enable = true;

  hardware.enableRedistributableFirmware = true;

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

  programs.nix-ld.enable = true;
}
