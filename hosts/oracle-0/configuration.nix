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

      encode gzip

      # Separate handles so hashed assets carry exactly one Cache-Control
      # value. A global `header Cache-Control no-store` plus a path-scoped
      # override emits BOTH headers (verified live 2026-09-06), leaving
      # caching ambiguous. The app serves these same values itself; Caddy
      # repeats them as the outer authority.
      handle /assets/* {
        # No Cache-Control here: the app serves immutable (verified) and any
        # Caddy repeat would double the header. The general handle below must
        # keep no-store — API responses set no Cache-Control themselves.
        # Security headers the app does not set itself (it owns only
        # COOP/COEP + Cache-Control; the release gate requires those
        # single-valued, so Caddy must not repeat them).
        header {
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
        reverse_proxy repertoire-builder:8090 {
          # Overwrite the client-IP header with the edge-verified client IP so
          # the app (which trusts only the bridge-gateway peer) rate-limits
          # per real client instead of one shared loopback bucket. Cloudflare
          # edge overwrites CF-Connecting-IP; only cloudflared dials this
          # loopback vhost.
          header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
        }
      }

      handle {
        # Prevent stale SPA shell caching (old HTML -> missing hashed chunks -> blank page)
        header Cache-Control "no-store"
        # Security headers the app does not set itself (see above).
        header {
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
        reverse_proxy repertoire-builder:8090 {
          # Overwrite the client-IP header with the edge-verified client IP
          # (see above).
          header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
        }
      }
    }

    http://vault.cernohorsky.ca {
      bind 127.0.0.1
      reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}

      encode gzip
    }

    http://metrics.cernohorsky.ca {
      bind 127.0.0.1
      reverse_proxy 127.0.0.1:${toString config.services.grafana.settings.server.http_port}

      encode gzip

      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
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
    ../../modules/nixos/tailscale-recover.nix
  ];

  # Determinate's builder lacks /dev/ptmx, so skip age's PTY tests (build is unaffected).
  nixpkgs.overlays = [
    (_final: prev: {
      age = prev.age.overrideAttrs (_old: {
        doCheck = false;
      });
    })
  ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      eval-cores = 1;
      trusted-users = [
        "root"
        "@wheel"
      ];
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

  # Passwordless sudo for matt only (not all future wheel members).
  security.sudo.extraConfig = "matt ALL=(ALL) NOPASSWD: ALL";

  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    wget
    ghostty.terminfo
    restic
    sqlite
  ];

  # Only management path is Tailscale SSH, so OpenSSH stays disabled.
  # agenix still needs an age identity: use the host ed25519 key directly.
  services.openssh.enable = false;
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Don't restart these during activation. Updates take effect on next reboot.
  # Tailscale is the only management path, so retry daemon failures indefinitely
  # instead of exhausting systemd's default five-start burst.
  systemd.services.tailscaled = {
    restartIfChanged = false;
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = lib.mkForce "5s";
  };
  systemd.services.systemd-resolved.restartIfChanged = false;

  # Secrets management
  age.secrets.tailscale-oracle-authkey.file = ../../secrets/tailscale-oracle-authkey.age;
  age.secrets.repertoire-auth = {
    file = ../../secrets/repertoire-auth.age;
    mode = "0400";
  };
  age.secrets.grafana-secret-key = {
    file = ../../secrets/grafana-secret-key.age;
    mode = "0400";
    owner = "grafana";
    group = "grafana";
  };

  # Tailscale VPN (tag:cloud is isolated, see tailscale-acl.json; SSH via Tailscale SSH only)
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
    authKeyFile = config.age.secrets.tailscale-oracle-authkey.path;
    # The credential is an OAuth client secret, whose default is an ephemeral
    # node. Oracle is a persistent server and must survive extended downtime.
    authKeyParameters = {
      ephemeral = false;
      preauthorized = true;
    };
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

  # Provide built frontend to the repertoire-builder container module.
  # The proxy peer as seen from inside the container is the bridge gateway
  # (verified 2026-09-06: br-containers 192.168.100.1/24, container .30,
  # Caddy dials the container IP directly, no host port forward).
  services.repertoire-builder.webDist =
    inputs.repertoire-builder.packages.${pkgs.stdenv.hostPlatform.system}.web;
  services.repertoire-builder.authSecretFile =
    config.age.secrets.repertoire-auth.path;
  services.repertoire-builder.trustedProxies = "192.168.100.1";

  # Disable documentation for minimal install.
  documentation.enable = false;

  system.stateVersion = "25.05";
}
