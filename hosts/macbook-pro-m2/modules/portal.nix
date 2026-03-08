# Portal - Mobile-first web UI for OpenCode
#
# This module sets up Portal (https://github.com/hosenur/portal) as a launchd
# user agent, exposed to your tailnet via `tailscale serve`.
#
# Access from iPhone: https://macbook-pro-m2.tailc41cf5.ts.net
#
# Architecture:
#   Portal (localhost:3000) -> OpenCode API (localhost:4096)
#   Tailscale Serve -> Portal (HTTPS on tailnet)
#
# The service runs as your user to access SSH keys, git credentials, and
# OpenCode auth tokens in ~/.local/share/opencode/
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.portal;

  # Portal package from npm (pre-built, includes web assets)
  openportal = pkgs.stdenv.mkDerivation {
    pname = "openportal";
    version = "0.1.24";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/openportal/-/openportal-0.1.24.tgz";
      hash = "sha256-sZc+cfXpHzGXc/nyPYLLCslOaZsEuFIjbR1J/5Oabnw=";
    };

    nativeBuildInputs = [ pkgs.gnutar ];

    unpackPhase = ''
      mkdir -p source
      tar -xzf $src -C source --strip-components=1
    '';

    installPhase = ''
      mkdir -p $out/lib/openportal $out/bin

      # Copy the pre-built dist and web directories
      cp -r source/dist $out/lib/openportal/
      cp -r source/web $out/lib/openportal/
      cp source/package.json $out/lib/openportal/

      # Create wrapper script that sets up the environment
      cat > $out/bin/openportal <<'WRAPPER'
      #!/usr/bin/env bash
      exec ${pkgs.bun}/bin/bun run ${placeholder "out"}/lib/openportal/dist/index.js "$@"
      WRAPPER
      chmod +x $out/bin/openportal

      # Create a launcher script that cleans stale entries before starting
      # This ensures the registry is fresh on each service restart
      cat > $out/bin/openportal-service <<'LAUNCHER'
      #!/usr/bin/env bash
      # Clean stale entries from ~/.portal.json before starting
      # This is needed because launchd restarts give us new PIDs
      ${pkgs.bun}/bin/bun run ${placeholder "out"}/lib/openportal/dist/index.js clean 2>/dev/null || true
      exec ${pkgs.bun}/bin/bun run ${placeholder "out"}/lib/openportal/dist/index.js "$@"
      LAUNCHER
      chmod +x $out/bin/openportal-service
    '';

    meta = {
      description = "Mobile-first web UI for OpenCode";
      homepage = "https://github.com/hosenur/portal";
      mainProgram = "openportal";
    };
  };

  # OpenCode package from llm-agents input
  opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in
{
  options.services.portal = {
    enable = lib.mkEnableOption "Portal web UI for OpenCode";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the Portal web UI (internal, localhost only)";
    };

    opencodePort = lib.mkOption {
      type = lib.types.port;
      default = 4096;
      description = "Port for the OpenCode API server (internal, localhost only)";
    };

    workingDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/Users/matt/Developer";
      description = "Default working directory for Portal/OpenCode sessions";
    };

    tailscaleServe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Portal to tailnet via tailscale serve (HTTPS)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure opencode and bun are available
    home.packages = [
      openportal
      opencode
      pkgs.bun
    ];

    # Portal launchd user agent
    # Runs openportal which manages both the web UI and OpenCode server
    # Uses openportal-service wrapper to clean stale registry entries on restart
    launchd.agents.portal = {
      enable = true;
      config = {
        ProgramArguments = [
          "${openportal}/bin/openportal-service"
          "--directory"
          (toString cfg.workingDirectory)
          "--port"
          (toString cfg.port)
          "--opencode-port"
          (toString cfg.opencodePort)
          "--hostname"
          "127.0.0.1"
        ];
        EnvironmentVariables = {
          # Ensure opencode is findable by Portal
          PATH = lib.concatStringsSep ":" [
            "${opencode}/bin"
            "${pkgs.bun}/bin"
            "${pkgs.coreutils}/bin"
            "${pkgs.git}/bin"
            "/usr/bin"
            "/bin"
          ];
          HOME = "/Users/matt";
          # Inherit user's shell environment for SSH agent, etc.
          SSH_AUTH_SOCK = "/Users/matt/.ssh/agent";
        };
        WorkingDirectory = toString cfg.workingDirectory;
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
        StandardOutPath = "/Users/matt/Library/Logs/portal.log";
        StandardErrorPath = "/Users/matt/Library/Logs/portal.error.log";
      };
    };
  };
}
