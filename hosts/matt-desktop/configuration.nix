{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Single source of truth for Stylix + hyprlock (same file as desktop wallpaper).
  stylixWallpaperImage =
    pkgs.runCommand "gruvbox-wallpaper.png"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        magick -size 3840x2160 \
          -define gradient:angle=135 \
          gradient:'#1d2021-#282828' \
          -blur 0x2 \
          $out
      '';
in

{

  home-manager.extraSpecialArgs = {
    inherit inputs stylixWallpaperImage;
  };

  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./modules/core.nix
    ./modules/nvidia.nix
    ./modules/desktop-services.nix
    ./modules/gaming.nix
    ./modules/media.nix
    ./modules/opencode-web.nix
    ./modules/niri.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2; # Faster boot menu

  networking.hostName = "matt-desktop";

  # Fix slow shutdown
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  users.users.matt = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "i2c"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca"
    ];
  };
  users.groups.netdev = { };

  # Restic REST Server for receiving backups from oracle-0
  # Security: Tailscale ACLs restrict access to tag:cloud only, appendOnly prevents deletion
  services.restic.server = {
    enable = true;
    dataDir = "/backups/oracle-0/vaultwarden";
    listenAddress = "8000";
    appendOnly = true;
    extraFlags = [ "--no-auth" ];
  };

  # Stylix system-wide theming
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    # Gruvbox dark palette
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    # Wallpaper: Replace stylixWallpaperImage in the let-block above (or point to a local file).
    image = stylixWallpaperImage;

    # Fonts (Using JetBrains Mono for everything)
    fonts = {
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      sansSerif = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      serif = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        terminal = 13;
        applications = 11;
        desktop = 11;
        popups = 11;
      };
    };
    cursor = {
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-light";
      size = 24;
    };
  };

  # OpenSSH: Keep enabled for agenix host keys, but prefer Tailscale SSH for access
  services.openssh = {
    enable = true;
    openFirewall = false; # Not exposed to internet, Tailscale SSH preferred
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Passwordless sudo for matt
  # Required by deploy-rs for remote NixOS activation.
  # This overrides wheelNeedsPassword from core.nix for user matt specifically.
  security.sudo.extraRules = [
    {
      users = [ "matt" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Secrets management
  age.secrets = {
    tailscale-authkey.file = ../../secrets/tailscale-authkey.age;
  };

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    openFirewall = true; # Allow UDP 41641 for direct connections
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraUpFlags = [
      "--advertise-tags=tag:trusted"
      "--ssh"
    ];
  };

  # Taildrive: Share main drives
  # Access via http://100.100.100.100:8080/<tailnet>/matt-desktop/<share>
  systemd.services.taildrive-shares = {
    description = "Configure Taildrive shares";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    partOf = [ "tailscaled.service" ]; # Restart when tailscaled restarts
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for Tailscale to be connected
      while ! ${pkgs.tailscale}/bin/tailscale status --peers=false 2>/dev/null | grep -q "100\."; do
        sleep 2
      done
      ${pkgs.tailscale}/bin/tailscale drive share ssd /
      ${pkgs.tailscale}/bin/tailscale drive share hdd /mnt/hdd
    '';
  };

  # Firewall: Restic REST Server only via Tailscale (SSH handled by Tailscale SSH)
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    8000
    13378
  ];

  # Samba: Share root filesystem over direct ethernet connection
  # Note: Can't use "bind interfaces only" as smbd crashes if interface missing
  services.samba = {
    enable = true;
    nmbd.enable = false; # Use Avahi instead for macOS discovery
    winbindd.enable = false; # Not needed for simple file sharing
    settings = {
      global = {
        # Only allow connections from direct ethernet link-local range (IPv4 and IPv6)
        "hosts allow" = "169.254. fe80::/10";
        "hosts deny" = "ALL";
      };
      root = {
        path = "/";
        browseable = "yes";
        "read only" = "no";
        "force user" = "matt";
      };
    };
  };
  networking.firewall.interfaces."enp4s0".allowedTCPPorts = [ 445 ];

  # Avahi: mDNS for Samba discovery from macOS Finder (enp4s0 only)
  # NOTE: Restricted to direct ethernet link. For general mDNS (printers, Chromecast),
  # remove allowInterfaces or add your main network interface.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    allowInterfaces = [ "enp4s0" ];
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles.smb = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
      </service-group>
    '';
  };

  # Backup directory for oracle-0 restic backups
  systemd.tmpfiles.rules = [
    "d /backups 0755 matt users -"
    "d /backups/oracle-0 0755 matt users -"
    "d /backups/oracle-0/vaultwarden 0755 restic restic -"
  ];

  # Local pruning of oracle-0 backups
  # oracle-0 can only append (REST server is append-only), matt-desktop prunes locally
  age.secrets.restic-password = {
    file = ../../secrets/restic-password.age;
    owner = "root";
    group = "root";
  };

  services.restic.backups.oracle-0-local-prune = {
    repository = "/backups/oracle-0/vaultwarden";
    passwordFile = config.age.secrets.restic-password.path;
    paths = [ ];

    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };

    # GFS retention policy (must match oracle-0 R2 backup)
    # hourly: 6 days of granular recovery (24 × 6hr intervals)
    # daily: 2 weeks, weekly: 2 months, monthly: 1 year, yearly: 2 years
    pruneOpts = [
      "--keep-hourly 24"
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
      "--keep-yearly 2"
    ];
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      eval-cores = 0;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://deploy-rs.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Fix Tailscale TPM issue after BIOS updates
  systemd.services.tailscaled.serviceConfig.Environment = [ "TS_NO_TPM=1" ];

  # Evdev-based idle tracker using python-evdev with select() for efficient blocking I/O
  # WORKAROUND: See detailed comment in home.nix
  systemd.user.services.evdev-idle-daemon =
    let
      evdev-idle-script =
        pkgs.writers.writePython3Bin "evdev-idle-daemon"
          {
            libraries = [ pkgs.python3Packages.evdev ];
            flakeIgnore = [
              "E302"
              "E305"
              "E501"
            ];
          }
          ''
            import os
            import select
            import subprocess
            import time

            from evdev import InputDevice, ecodes, list_devices

            ACTIVITY_TYPES = {ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_ABS}
            LOCK_AFTER = 30 * 60  # 30 minutes
            DPMS_AFTER = 60 * 60  # 60 minutes
            LOCK_GRACE = 3  # require lock to settle before monitor power-off
            DISPLAY_RELOCK_DELAY = 15  # avoid immediate re-lock loops after display wake
            LOCK_CHECK_INTERVAL = 1  # wake periodically to evaluate lock deadlines

            DEBUG = os.environ.get("EVDEV_IDLE_DEBUG", "0") == "1"

            LOCK_EXE = os.environ["EVDEV_LOCK_EXE"]
            LOCK_PROC_NAME = os.environ["EVDEV_LOCK_PROC"]
            LOCK_CMD = [LOCK_EXE]

            def debug(msg):
                if DEBUG:
                    print(f"evdev-idle: {msg}", flush=True)

            NIRI_CMD = "${config.programs.niri.package}/bin/niri"
            LOGINCTL_CMD = "${pkgs.systemd}/bin/loginctl"
            PGREP_CMD = "${pkgs.procps}/bin/pgrep"
            PKILL_CMD = "${pkgs.procps}/bin/pkill"


            def run_niri_action(action):
                try:
                    debug(f"running niri action: {action}")
                    subprocess.run(
                        [NIRI_CMD, "msg", "action", action],
                        capture_output=True,
                        timeout=5,
                        check=False,
                    )
                    return True
                except Exception as err:
                    print(f"evdev-idle: niri action '{action}' failed: {err}", flush=True)
                    return False


            def is_session_locked():
                session_id = os.environ.get("XDG_SESSION_ID")
                if not session_id:
                    return False

                try:
                    result = subprocess.run(
                        [LOGINCTL_CMD, "show-session", session_id, "-p", "LockedHint", "--value"],
                        capture_output=True,
                        text=True,
                        timeout=2,
                        check=False,
                    )
                    return result.returncode == 0 and result.stdout.strip().lower() == "yes"
                except Exception:
                    return False


            def find_input_devices():
                devices = {}
                for path in list_devices():
                    dev = InputDevice(path)
                    caps = dev.capabilities()
                    debug(f"considering {path} {dev.name} caps={sorted(caps.keys())}")
                    if ACTIVITY_TYPES & set(caps.keys()):
                        devices[dev.fd] = dev
                return devices


            def lock_process_running(lock_proc):
                return lock_proc is not None and lock_proc.poll() is None


            def now_locked(lock_proc):
                return is_session_locked() or lock_process_running(lock_proc)


            def cleanup_stale_locker():
                try:
                    subprocess.run(
                        [PKILL_CMD, "-x", LOCK_PROC_NAME],
                        capture_output=True,
                        timeout=2,
                        check=False,
                    )
                    time.sleep(0.2)
                except Exception:
                    pass


            def locker_process_exists():
                try:
                    result = subprocess.run(
                        [PGREP_CMD, "-x", LOCK_PROC_NAME],
                        capture_output=True,
                        text=True,
                        timeout=2,
                        check=False,
                    )
                    return result.returncode == 0 and bool(result.stdout.strip())
                except Exception:
                    return False


            def start_lock(lock_proc):
                if lock_process_running(lock_proc) or is_session_locked():
                    debug("locker already active, skipping new lock launch")
                    return lock_proc

                if locker_process_exists():
                    debug("stale locker process detected, cleaning up")
                    cleanup_stale_locker()
                    if locker_process_exists():
                        print("evdev-idle: stale locker remains; skipping new lock launch", flush=True)
                        return lock_proc

                try:
                    proc = subprocess.Popen(
                        LOCK_CMD,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    print(f"evdev-idle: lock process started pid={proc.pid}", flush=True)
                    return proc
                except Exception as err:
                    print(f"evdev-idle: failed to start locker: {err}", flush=True)
                    return None


            def main():
                devices = find_input_devices()
                if not devices:
                    print("evdev-idle: no input devices found, exiting", flush=True)
                    return 1

                print(f"evdev-idle: monitoring {len(devices)} input devices", flush=True)

                last_activity = time.monotonic()
                monitors_off = False
                lock_proc = None
                next_lock_attempt = 0.0
                lock_confirmed_at = None

                while True:
                    if lock_proc is not None and lock_proc.poll() is not None:
                        print(f"evdev-idle: lock process exited rc={lock_proc.returncode}", flush=True)
                        lock_proc = None

                    now = time.monotonic()
                    locked_hint_initial = is_session_locked()
                    lock_active = now_locked(lock_proc)
                    if locked_hint_initial:
                        if lock_confirmed_at is None:
                            lock_confirmed_at = now
                    else:
                        lock_confirmed_at = None

                    next_lock = (last_activity + LOCK_AFTER) if not lock_active else float("inf")
                    next_dpms = last_activity + DPMS_AFTER
                    timeout = max(0, min(min(next_lock, next_dpms) - now, LOCK_CHECK_INTERVAL))

                    try:
                        ready, _, _ = select.select(list(devices.values()), [], [], timeout)
                    except Exception:
                        ready = []

                    if ready:
                        saw_activity = False
                        for dev in ready:
                            try:
                                for ev in dev.read():
                                    if ev.type in ACTIVITY_TYPES:
                                        saw_activity = True
                                        debug(f"activity from {dev.path} {dev.name}: type={ev.type} code={ev.code} value={ev.value}")
                            except BlockingIOError:
                                pass

                        if saw_activity:
                            last_activity = time.monotonic()
                            next_lock_attempt = 0.0
                            if monitors_off and run_niri_action("power-on-monitors"):
                                print("evdev-idle: monitors woke from activity", flush=True)
                                monitors_off = False
                                lock_confirmed_at = None
                                # Give compositor/locker time to settle after wake.
                                last_activity = max(last_activity, time.monotonic() - LOCK_AFTER + DISPLAY_RELOCK_DELAY)
                            continue

                    now = time.monotonic()
                    locked_hint = is_session_locked()
                    lock_active = now_locked(lock_proc)
                    if locked_hint:
                        if lock_confirmed_at is None:
                            lock_confirmed_at = now
                    else:
                        lock_confirmed_at = None

                    should_lock = (not lock_active) and (now - last_activity >= LOCK_AFTER) and (now >= next_lock_attempt)

                    if should_lock:
                        debug("lock timeout reached, starting locker")
                        lock_proc = start_lock(lock_proc)
                        next_lock_attempt = now + 5.0
                        continue

                    if not monitors_off and now - last_activity >= DPMS_AFTER:
                        # Ensure session is locked before powering monitors off.
                        if not locked_hint:
                            if not lock_process_running(lock_proc) and now >= next_lock_attempt:
                                debug("dpms timeout reached without lock hint, retrying locker")
                                lock_proc = start_lock(lock_proc)
                                next_lock_attempt = now + 5.0
                            continue

                        # Prevent race where monitor powers off exactly at lock acquisition.
                        if lock_confirmed_at is None or (now - lock_confirmed_at) < LOCK_GRACE:
                            debug("lock confirmed too recently; delaying monitor power-off")
                            continue

                        if run_niri_action("power-off-monitors"):
                            print("evdev-idle: monitors powered off", flush=True)
                            monitors_off = True

                return 0


            if __name__ == "__main__":
                exit(main())
          '';
    in
    {
      description = "Evdev-based idle tracker (workaround for Smithay idle bug)";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${evdev-idle-script}/bin/evdev-idle-daemon";
        Environment = [
          "PYTHONUNBUFFERED=1"
          "EVDEV_LOCK_EXE=${pkgs.hyprlock}/bin/hyprlock"
          "EVDEV_LOCK_PROC=hyprlock"
        ];
        StandardOutput = "journal";
        StandardError = "journal";
        Restart = "always";
        RestartSec = 5;
        KillMode = "mixed";
      };
    };

  # Btrfs snapshot management for /home
  # Snapshots accessible at /btr_pool/@snapshots/@home.<date>
  services.btrbk.instances.home = {
    onCalendar = "daily";
    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = "7d 4w";
      volume."/btr_pool" = {
        subvolume."@home" = {
          snapshot_dir = "@snapshots";
        };
      };
    };
  };

  # Mount raw btrfs root for btrbk snapshot access
  fileSystems."/btr_pool" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [
      "subvolid=5"
      "noatime"
    ];
  };

  system.stateVersion = "25.05";
}
