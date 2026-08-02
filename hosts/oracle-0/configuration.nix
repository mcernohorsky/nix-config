{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # External Linux builds see the physical macOS store, where Nix rewrites
  # case-colliding ncurses directories. Copy only the four entries needed by
  # systemd stage 1 into a collision-free output. `nix copy` restores normal
  # names on Linux; this is needed only while assembling the initrd locally.
  initrdTerminfo = pkgs.runCommand "initrd-terminfo" { } ''
    mkdir -p "$out/l" "$out/v"

    for entry in linux vt100 vt102 vt220; do
      source="$(find ${pkgs.ncurses}/share/terminfo -type f -name "$entry" -print -quit)"
      test -n "$source"
      if test "$entry" = linux; then
        cp "$source" "$out/l/$entry"
      else
        cp "$source" "$out/v/$entry"
      fi
    done
  '';

  # An explicit Caddyfile is a supported NixOS configuration path and avoids
  # nixpkgs' optional formatting derivation, whose `cp --no-preserve=mode`
  # attempts a chmod that the Determinate native builder's output mount rejects.
  caddyConfigFile = pkgs.writeText "Caddyfile" ''
    {
      auto_https off
    }

    http://cernohorsky.ca {
      bind 127.0.0.1
      respond "Matt's website will be here someday." 200
    }

    http://chess.cernohorsky.ca {
      bind 127.0.0.1
      reverse_proxy repertoire-builder:8090

      encode gzip

      # Prevent stale SPA shell caching (old HTML -> missing hashed chunks -> blank page)
      header Cache-Control "no-store"
      # Allow long-lived caching for content-hashed JS/CSS assets
      header /_app/immutable/* Cache-Control "public, max-age=31536000, immutable"

      header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        # Required for SharedArrayBuffer (Stockfish WASM threading)
        # Using credentialless instead of require-corp for broader compatibility
        # with external resources (fonts, analytics, etc.)
        Cross-Origin-Opener-Policy "same-origin"
        Cross-Origin-Embedder-Policy "credentialless"
      }
    }
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    inputs.repertoire-builder.nixosModules.container
    ./modules/networking.nix
    ./modules/monitoring.nix
    ./modules/security.nix
    ./modules/vaultwarden.nix
    ./modules/backup.nix
  ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      eval-cores = 1;
      extra-substituters = [
        "https://deploy-rs.cachix.org"
      ];
      extra-trusted-public-keys = [
        "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.systemd = {
      enable = true;
      contents = {
        "/etc/terminfo/l/linux".source = lib.mkForce "${initrdTerminfo}/l/linux";
        "/etc/terminfo/v/vt100".source = lib.mkForce "${initrdTerminfo}/v/vt100";
        "/etc/terminfo/v/vt102".source = lib.mkForce "${initrdTerminfo}/v/vt102";
        "/etc/terminfo/v/vt220".source = lib.mkForce "${initrdTerminfo}/v/vt220";
      };
    };
  };

  systemd.targets.multi-user.enable = true;

  networking.hostName = "oracle-0";

  time.timeZone = "America/Edmonton";
  i18n.defaultLocale = "en_CA.UTF-8";

  users = {
    mutableUsers = false;
    users.matt = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca"
      ];
    };
  };

  # Enable passwordless sudo.
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

  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    wget
    ghostty.terminfo
    restic
    sqlite
  ];

  # --- DEPLOYMENT / ACCESS TRANSPORT ---
  # IMPORTANT: deploy-rs activation currently restarts tailscaled during the switch.
  # Since Tailscale is our ONLY network path, that drops the SSH control channel and triggers deploy-rs rollback.
  #
  # Safer two-step rollout:
  # 1) Keep OpenSSH enabled while enabling Tailscale SSH ("--ssh"). Deploy and verify TS SSH works.
  # 2) In a follow-up deploy, disable OpenSSH.
  #
  # We are now in step (2): Tailscale SSH works (see tailscaled ssh-session journal entries).
  #
  # NOTE: we still need an SSH host key available for agenix, even if OpenSSH is disabled.
  # See: age.identityPaths below.
  services.openssh.enable = false;

  # agenix needs an age identity. When OpenSSH is disabled, NixOS can't auto-derive it from
  # ssh host keys, so we point it at the existing host ed25519 key.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Don't restart these during activation. Updates take effect on next reboot.
  # Tailscale is the only management path, so retry daemon failures indefinitely
  # instead of exhausting systemd's default five-start burst.
  systemd.services.tailscaled = {
    restartIfChanged = false;
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = lib.mkForce "5s";
  };
  systemd.services.systemd-networkd.restartIfChanged = false;
  systemd.services.systemd-resolved.restartIfChanged = false;

  # Secrets management
  age.secrets.tailscale-authkey.file = ../../secrets/tailscale-authkey.age;
  age.secrets.pocketbase-superuser = {
    file = ../../secrets/pocketbase-superuser.age;
    mode = "0400";
  };
  age.secrets.grafana-secret-key = {
    file = ../../secrets/grafana-secret-key.age;
    mode = "0400";
    owner = "grafana";
    group = "grafana";
  };

  # Tailscale VPN
  # Note: tag:cloud is isolated - see tailscale-acl.json for policy
  # SSH access is via Tailscale SSH (--ssh flag), OpenSSH is disabled
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraUpFlags = [
      "--advertise-tags=tag:cloud"
      "--ssh"
    ];
  };

  # Taildrive: Share root filesystem
  # Access via http://100.100.100.100:8080/<tailnet>/oracle-0/root
  systemd.services.taildrive-shares = {
    description = "Configure Taildrive shares";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "30s";
      ExecStart = "${pkgs.tailscale}/bin/tailscale drive share root /";
    };
  };

  services.caddy = {
    enable = true;
    configFile = caddyConfigFile;
  };

  # Provide built frontend to the repertoire-builder container module
  services.repertoire-builder.webDist =
    inputs.repertoire-builder.packages.${pkgs.stdenv.hostPlatform.system}.web;
  services.repertoire-builder.superuserPasswordFile = config.age.secrets.pocketbase-superuser.path;

  # Configure nix for deployment
  nix.settings.trusted-users = [ "@wheel" ];

  # Disable autologin.
  services.getty.autologinUser = null;

  # Disable documentation for minimal install.
  documentation.enable = false;

  system.stateVersion = "25.05";
}
