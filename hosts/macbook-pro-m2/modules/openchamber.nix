# OpenChamber — web UI for OpenCode (https://github.com/openchamber/openchamber)
#
# Uses the published npm package @openchamber/web (built from packages/web in that repo)
# as a launchd user agent, exposed to your tailnet via `tailscale serve`.
#
# Access from iPhone: https://macbook-pro-m2.tailc41cf5.ts.net
#
# We run server/index.js with Bun directly (not the `openchamber` CLI): the CLI
# daemonizes and exits, which does not work under launchd.
#
# Architecture:
#   OpenChamber (localhost:3000) -> OpenCode API (localhost:4097 by default)
#   Tailscale Serve -> OpenChamber (HTTPS on tailnet)
#
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.openchamber;
  pin = builtins.fromJSON (builtins.readFile ./openchamber-pin.json);

  # Build from the published npm tarball using a checked-in package-lock.
  openchamber = pkgs.buildNpmPackage {
    pname = "openchamber-web";
    version = pin.version;
    src = pkgs.fetchurl {
      url = pin.url;
      hash = pin.srcHash;
    };
    sourceRoot = "package";
    postPatch = ''
      cp ${./openchamber-package-lock.json} package-lock.json
    '';
    npmDepsHash = pin.npmDepsHash;
    dontNpmBuild = true;
    installPhase = ''
            runHook preInstall
            pkg="$out/lib/node_modules/@openchamber/web"
            mkdir -p "$pkg" "$out/bin"
            cp -r . "$pkg"
            cat > "$out/bin/openchamber" <<EOF
      #!${pkgs.bash}/bin/bash
      exec ${pkgs.bun}/bin/bun "$pkg/bin/cli.js" "\$@"
      EOF
            chmod +x "$out/bin/openchamber"
            runHook postInstall
    '';
  };

  opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

  serverJs = "${openchamber}/lib/node_modules/@openchamber/web/server/index.js";
in
{
  options.services.openchamber = {
    enable = lib.mkEnableOption "OpenChamber web UI for OpenCode";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the OpenChamber web UI (internal, localhost only)";
    };

    opencodePort = lib.mkOption {
      type = lib.types.port;
      default = 4096;
      description = "Port for the OpenCode API server (internal, localhost only)";
    };

    workingDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/Users/matt/Developer";
      description = "Default working directory for OpenChamber / OpenCode sessions";
    };

    tailscaleServe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Documented alongside tailscale serve; run `just openchamber-reset-serve` after port changes";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      openchamber
      opencode
    ];

    launchd.agents.openchamber = {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.bun}/bin/bun"
          serverJs
          "--port"
          (toString cfg.port)
        ];
        EnvironmentVariables = {
          PATH = lib.concatStringsSep ":" [
            "${opencode}/bin"
            "${pkgs.bun}/bin"
            "${pkgs.nodejs}/bin"
            "${pkgs.coreutils}/bin"
            "${pkgs.git}/bin"
            "/usr/bin"
            "/bin"
          ];
          HOME = "/Users/matt";
          SSH_AUTH_SOCK = "/Users/matt/.ssh/agent";
          OPENCODE_BINARY = "${opencode}/bin/opencode";
          OPENCODE_PORT = toString cfg.opencodePort;
        };
        WorkingDirectory = toString cfg.workingDirectory;
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
        StandardOutPath = "/Users/matt/Library/Logs/openchamber.log";
        StandardErrorPath = "/Users/matt/Library/Logs/openchamber.error.log";
      };
    };
  };
}
