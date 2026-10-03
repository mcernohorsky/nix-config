{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Linux builds on the Mac's native builder see the case-insensitive macOS
  # store, where Nix renames case-colliding ncurses entries. Copy the four
  # terminfo entries systemd stage 1 needs into a collision-free output.
  terminfo = [
    "l/linux"
    "v/vt100"
    "v/vt102"
    "v/vt220"
  ];
  initrdTerminfo = pkgs.runCommand "initrd-terminfo" { } ''
    for entry in ${toString terminfo}; do
      source="$(find ${pkgs.ncurses}/share/terminfo -type f -name "$(basename "$entry")" -print -quit)"
      install -D "$source" "$out/$entry"
    done
  '';

  # An explicit Caddyfile skips nixpkgs' formatting derivation, whose
  # `cp --no-preserve=mode` chmod fails on the Determinate builder's mount.
  # Cloudflare Tunnel is the only client, so everything binds to loopback.
  caddyfile = pkgs.writeText "Caddyfile" ''
    {
      auto_https off
    }

    (common) {
      bind 127.0.0.1
      encode gzip
      header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }

    http://cernohorsky.ca {
      bind 127.0.0.1
      respond "Matt's website will be here someday." 200
    }

    http://chess.cernohorsky.ca {
      import common
      # Hashed assets are served immutable by the app. Everything else is
      # no-store so a stale SPA shell cannot reference missing chunks; `>`
      # replaces the app's own value so the header stays single-valued.
      @mutable not path /assets/*
      header @mutable >Cache-Control "no-store"
      # The app trusts only the bridge gateway, so pass the edge-verified
      # client IP for per-client rate limiting.
      reverse_proxy repertoire-builder:8090 {
        header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
      }
    }

    http://vault.cernohorsky.ca {
      bind 127.0.0.1
      encode gzip
      reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
    }

    http://groundwork.cernohorsky.ca {
      import common
      # The app rate-limits sign-in by CF-Connecting-IP, passed through as-is.
      reverse_proxy groundwork:7171
    }

    http://metrics.cernohorsky.ca {
      import common
      header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      reverse_proxy 127.0.0.1:${toString config.services.grafana.settings.server.http_port}
    }
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    inputs.repertoire-builder.nixosModules.container
    inputs.groundwork.nixosModules.container
    ./modules/backup.nix
    ./modules/monitoring.nix
    ./modules/networking.nix
    ./modules/security.nix
    ./modules/vaultwarden.nix
  ];

  networking.hostName = "oracle-0";
  system.stateVersion = "25.05";
  documentation.enable = false;

  # Determinate's builder lacks /dev/ptmx, so skip age's PTY tests.
  nixpkgs.overlays = [
    (_final: prev: {
      age = prev.age.overrideAttrs { doCheck = false; };
    })
  ];

  nix = {
    settings.eval-cores = 1;
    gc.options = "--delete-older-than 14d";
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.systemd = {
      enable = true;
      contents = lib.listToAttrs (
        map (
          entry:
          lib.nameValuePair "/etc/terminfo/${entry}" {
            source = lib.mkForce "${initrdTerminfo}/${entry}";
          }
        ) terminfo
      );
    };
  };

  users.mutableUsers = false;

  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    wget
    ghostty.terminfo
    restic
    sqlite
  ];

  # Tailscale SSH is the only management path. agenix uses the host key.
  services.openssh.enable = false;
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    tailscale-oracle-authkey.file = ../../secrets/tailscale-oracle-authkey.age;
    repertoire-auth.file = ../../secrets/repertoire-auth.age;
    grafana-secret-key = {
      file = ../../secrets/grafana-secret-key.age;
      owner = "grafana";
    };
  };

  # tag:cloud is isolated from other devices by tailscale-acl.json.
  services.tailscale = {
    useRoutingFeatures = "server";
    authKeyFile = config.age.secrets.tailscale-oracle-authkey.path;
    extraUpFlags = [ "--advertise-tags=tag:cloud" ];
  };
  services.taildrive.shares.root = "/";

  services.caddy = {
    enable = true;
    configFile = caddyfile;
  };

  # Caddy dials the container IP directly; the app sees the bridge gateway
  # (br-containers 192.168.100.1) as its proxy peer.
  services.repertoire-builder = {
    webDist = inputs.repertoire-builder.packages.${pkgs.stdenv.hostPlatform.system}.web;
    authSecretFile = config.age.secrets.repertoire-auth.path;
    trustedProxies = "192.168.100.1";
  };

  # Data in /var/lib/containers/groundwork. A new server logs a setup code:
  # `just groundwork-logs`.
  services.groundwork.publicUrl = "https://groundwork.cernohorsky.ca";
}
