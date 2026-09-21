{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.opencodeV2;

  # Points Tailscale Serve at the normal OpenCode managed background
  # service. Reads the registered localhost URL from the state file,
  # health-checks it with the managed credentials, and proxies it.
  # Never logs the password. Safe to run repeatedly; concurrent runs are
  # harmless because every run converges on the same current endpoint and
  # Serve replacement is atomic.
  opencode-tailscale-sync = pkgs.writeShellApplication {
    name = "opencode-tailscale-sync";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.curl
      pkgs.python3
    ];
    text = ''
            set -euo pipefail

            state_file="''${OPENCODE_SERVICE_FILE:-''${XDG_STATE_HOME:-$HOME/.local/state}/opencode/service.json}"
            marker_file="$(dirname "$state_file")/tailscale-sync-target"

            # Remove our Serve mapping only when provably stale: the state file
            # is gone and the whole Serve config is just our last mapping.
            prune_if_stale() {
              [ -f "$marker_file" ] || return 0
              marker="$(cat "$marker_file")"
              if tailscale serve status --json 2>/dev/null | python3 -c '
      import json,sys
      try:
        status = json.load(sys.stdin)
      except Exception:
        sys.exit(1)
      web = status.get("Web", {})
      if len(web) != 1:
        sys.exit(1)
      handlers = next(iter(web.values())).get("Handlers", {})
      if handlers != {"/": {"Proxy": sys.argv[1]}}:
        sys.exit(1)
      ' "$marker"; then
                stale="''${marker#http://}"
                tailscale serve reset
                rm -f "$marker_file"
                echo "opencode-tailscale-sync: pruned stale mapping $stale"
              fi
            }

            if [ ! -f "$state_file" ]; then
              prune_if_stale
              echo "opencode-tailscale-sync: no service state yet, skipping"
              exit 0
            fi

            # Single snapshot so URL and password cannot mix generations.
            snapshot="$(cat "$state_file")"
            oc_url="$(printf '%s' "$snapshot" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url", ""))')"
            password="$(printf '%s' "$snapshot" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("password", ""))')"

            # Canonicalize and refuse anything but plain loopback HTTP. This
            # runs before any credential leaves the machine, so a crafted URL
            # such as http://localhost:80@evil cannot receive the password.
            canonical="$(python3 -c '
      import sys,urllib.parse
      u = urllib.parse.urlparse(sys.argv[1])
      if (u.scheme == "http" and u.hostname in ("127.0.0.1", "localhost")
          and isinstance(u.port, int) and 1 <= u.port <= 65535
          and not u.username and not u.password
          and u.path in ("", "/") and not u.query and not u.fragment):
        print(f"http://{u.hostname}:{u.port}")
      else:
        print("")
      ' "$oc_url")"
            if [ -z "$canonical" ]; then
              echo "opencode-tailscale-sync: refusing non-localhost endpoint, leaving Serve unchanged" >&2
              exit 0
            fi
            if [ -z "$password" ]; then
              echo "opencode-tailscale-sync: no credentials in service state, skipping" >&2
              exit 0
            fi

            oc_host="''${canonical#http://}"
            oc_host="''${oc_host%:*}"

            if ! curl -fsS --noproxy '*' --connect-timeout 5 --max-time 15 \
              --netrc-file <(printf 'machine %s login opencode password %s\n' "$oc_host" "$password") \
              "$canonical/global/health" -o /dev/null; then
              echo "opencode-tailscale-sync: service unhealthy, leaving Serve unchanged" >&2
              exit 0
            fi

            # Abort if the service re-registered while we were checking.
            if [ "$(cat "$state_file")" != "$snapshot" ]; then
              echo "opencode-tailscale-sync: endpoint changed mid-sync, skipping"
              exit 0
            fi

            tailscale serve --bg "$canonical"
            printf '%s' "$canonical" > "$marker_file"
            echo "opencode-tailscale-sync: Serve now proxies ''${canonical#http://}"
    '';
  };

  # Connects a local OpenCode client to another tailnet host's managed
  # service. Fetches that host's current pairing password over Tailscale
  # SSH and keeps it in the child process environment only (exported, so
  # it never appears in process arguments).
  opencode-remote = pkgs.writeShellApplication {
    name = "opencode-remote";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.openssh
      pkgs.python3
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      target="''${1:-}"
      if [ $# -gt 0 ]; then shift; fi
      # Accept and drop one `--` separator: ocd -- --continue, etc.
      if [ "''${1:-}" = "--" ]; then shift; fi

      case "$target" in
        mac) host="macbook-pro-m2.tailc41cf5.ts.net" ;;
        desktop) host="matt-desktop.tailc41cf5.ts.net" ;;
        oracle)
          echo "opencode-remote: Oracle OpenCode is not enabled yet" >&2
          exit 2
          ;;
        *)
          echo "usage: opencode-remote <mac|desktop|oracle> [-- opencode args...]" >&2
          exit 2
          ;;
      esac

      cli="$HOME/.bun/bin/opencode"
      if [ ! -x "$cli" ]; then
        if [ -x "$HOME/.bun/bin/opencode2" ]; then cli="$HOME/.bun/bin/opencode2"; else cli="opencode"; fi
      fi

      # One round trip: wake the remote managed service if needed, then
      # print its registration. Harmless when already running.
      # SC2016 is a false positive below: $HOME/$R must stay literal —
      # they expand on the remote host, not locally.
      # shellcheck disable=SC2016
      remote_cmd='if [ -x "$HOME/.bun/bin/opencode" ]; then R="$HOME/.bun/bin/opencode"; elif [ -x "$HOME/.bun/bin/opencode2" ]; then R="$HOME/.bun/bin/opencode2"; else R="opencode"; fi; "$R" service start >/dev/null 2>&1 || true; cat ~/.local/state/opencode/service.json'
      # Transport is per target and always over the tailnet. `tailscale ssh`
      # tracks host keys through node-key rotations via the coordination
      # server, so it is the default — except toward the Mac. ssh-rule
      # destinations cannot address a user-owned device without tagging it,
      # so the Mac serves plain OpenSSH instead and filter rules govern that
      # direction. Its Apple host keys never rotate, so accept-new pins them
      # once and still alarms on any later change. (`tailscale ssh` takes no
      # ssh flags, so `timeout` bounds its dial instead of ConnectTimeout.)
      if [ "$target" = "mac" ]; then
        state_json="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "matt@$host" "$remote_cmd")" || {
          echo "opencode-remote: no managed service on $host yet (launch OpenCode there once)" >&2
          exit 1
        }
      else
        state_json="$(timeout -s KILL 20 tailscale ssh "matt@$host" "$remote_cmd")" || {
          echo "opencode-remote: no managed service on $host yet (launch OpenCode there once)" >&2
          exit 1
        }
      fi
      password="$(printf '%s' "$state_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])')"

      # Wait for the remote watcher to publish the endpoint (bounded:
      # path watcher fires immediately, timer/poll within ~60s).
      attempts=0
      until curl -fsS --connect-timeout 3 --max-time 10 \
        --netrc-file <(printf 'machine %s login opencode password %s\n' "$host" "$password") \
        "https://$host/global/health" -o /dev/null 2>/dev/null; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 12 ]; then
          echo "opencode-remote: https://$host not healthy after ~60s; retry shortly" >&2
          exit 1
        fi
        sleep 5
      done

      export OPENCODE_SERVER_PASSWORD="$password"
      export OPENCODE_PASSWORD="$password"
      # Stable flag parsing accepts --server only after the subcommand
      # (`opencode api --server <url> ...`); the beta-style global prefix
      # (`opencode --server <url> <subcommand>`) prints usage instead.
      exec "$cli" "$@" --server "https://$host"
    '';
  };

  # Prints the unpacked extension directory for the bun-global install.
  # Upstream documents `npm root --global`, which does not apply to the
  # bun + Nix layout used here (~/.bun/install/global/...).
  browser-control-extension-path = pkgs.writeShellApplication {
    name = "browser-control-extension-path";
    text = ''
      ext="$HOME/.bun/install/global/node_modules/@opencode-ai/browser-control/extension/dist"
      printf '%s\n' "$ext"
      if [ ! -f "$ext/manifest.json" ]; then
        echo "browser-control-extension-path: extension not found at $ext (run: bun install -g --trust @opencode-ai/browser-control)" >&2
        exit 1
      fi
    '';
  };
in
{
  options.modules.home.opencodeV2.enable = lib.mkEnableOption "OpenCode v2";

  config = lib.mkIf cfg.enable {
    # OpenCode v2's supported installer is Bun. Keep the application in
    # Bun's writable user prefix so its self-updater can work.
    home = {
      packages = [
        pkgs.bun
        opencode-tailscale-sync
        opencode-remote
        browser-control-extension-path
      ];
      sessionPath = lib.mkAfter [ "$HOME/.bun/bin" ];
      shellAliases = {
        oc = "opencode";
        ocm = "opencode-remote mac";
        ocd = "opencode-remote desktop";
        oco = "opencode-remote oracle";
      };
    };

    # Nushell does not consume Home Manager's POSIX session-variable script.
    # Set its structured PATH directly so `nu` also works when it is launched
    # without an intermediate Bash or Zsh login shell.
    programs.nushell.extraEnv = lib.mkAfter ''
      let bun_bin_dir = ($nu.home-dir | path join ".bun" "bin")
      $env.PATH = (
        $env.PATH
        | prepend $bun_bin_dir
        | uniq
      )
    '';

    # Reviewer plugin ships as repo-local .opencode/plugins (auto-loaded,
    # proven mechanism). The HM-managed absolute-path plugin dir NEVER
    # loaded (zero loader lines across restarts; absolute-path global
    # plugins appear unsupported in v2), so that vehicle is out.
    # Single source: .opencode/plugins/muse-auto-review/index.ts.

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = true;
      # Global default model. No variant here: the muse routing subagent
      # below pins xhigh explicitly. Astra stays manually selectable and is
      # never the global default.
      model = "opencode-go/muse-spark-1.3-contributor";
      # Ask by default is SUSPENDED 2026-09-08: ctx.session.generate runs
      # the review with FULL session context on the session model, so every
      # risky action costs ~2x model and caused rate-limit errors. Do not
      # re-enable default-ask until the reviewer is an isolated cheap call
      # (fix generate-text routing or use a small model) and in-hook notes
      # are proven to land. Permissive shell restored meanwhile.
      # Subagent launches: routine targets (muse, explore, general) run
      # free; everything else (incl. Astra) asks and the reviewer judges
      # it from chat. No per-agent hardcode on the restricted side — the
      # trailing * is the gate. (Each gated launch costs one review call.)
      permissions = [
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "rm -rf *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "sudo rm -rf *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "git push *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "echo *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "printf *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "pwd";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "ls *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "whoami";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "hostname";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "date *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "uname *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "true";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "basename *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "dirname *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "head *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "tail *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "wc *";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "muse";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "explore";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "general";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "*";
          effect = "ask";
        }
      ];
      # Model-routing subagents only. Build and Plan are intentionally left
      # untouched so upstream improvements keep applying. All entries are
      # mode = "subagent", so they never appear as primary agents.
      # No subagent_depth is set: OpenCode's default one-hop behavior stays.
      agents = {
        muse = {
          mode = "subagent";
          model = "opencode-go/muse-spark-1.3-contributor#xhigh";
          description = ''
            Muse Spark 1.3 Contributor at XHIGH reasoning.

            Always use this target when delegating work to Muse.

            It is appropriate for implementation, research, exploration, review,
            parallelizable work, and cheaper supporting work when the primary model
            is GPT-6 Astra.
          '';
        };
        astra = {
          mode = "subagent";
          model = "openai/gpt-6-astra#low";
          steps = 30;
          description = ''
            GPT-6 Astra at LOW reasoning.

            This is the default Astra target. Use it whenever Astra is requested
            without a reasoning level.

            If the user explicitly requests medium or high reasoning, use the
            matching astra-medium or astra-high subagent instead. There are no
            higher-level Astra subagents: for xhigh or max, the user runs Astra
            directly as the primary model.

            Complete the assigned task and return a useful report/result to the
            parent agent. If approaching the step limit, prioritize reporting
            findings, completed work, unresolved issues, and recommended next actions.
          '';
        };
        astra-medium = {
          mode = "subagent";
          model = "openai/gpt-6-astra#medium";
          steps = 30;
          description = ''
            GPT-6 Astra at MEDIUM reasoning.
            Use when the user explicitly requests Astra medium.
            Complete the assigned task and return the result to the parent.
          '';
        };
        astra-high = {
          mode = "subagent";
          model = "openai/gpt-6-astra#high";
          steps = 30;
          description = ''
            GPT-6 Astra at HIGH reasoning.
            Use when the user explicitly requests Astra high.
            Complete the assigned task and return the result to the parent.
          '';
        };
      };
    };

    # Bootstrap a fresh machine, then let OpenCode maintain its own
    # binary. Normal Home Manager activations do not reinstall it.
    # Migrates the beta layout: stable package is @opencode/cli (binary
    # `opencode`, with an `opencode2` compat shim), replacing
    # @opencode-ai/cli@beta (`opencode2` only).
    home.activation.installOpenCodeV2 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.bun/bin/opencode" ]; then
        run ${lib.getExe pkgs.bun} install -g --trust @opencode/cli
      fi
      if [ -d "$HOME/.bun/install/global/node_modules/@opencode-ai/cli" ]; then
        run ${lib.getExe pkgs.bun} remove -g @opencode-ai/cli || true
      fi
    '';

    # Browser Control drives the existing Chromium-family browser (Helium
    # here) through a local relay + extension. OpenCode runs it via shell,
    # so no opencode.json MCP entry is needed (skill-only, per upstream).
    # Same bun-global pattern as OpenCode: bootstrap once, update explicitly
    # with `bun install -g --trust @opencode-ai/browser-control`.
    home.activation.installBrowserControl = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.bun/bin/browser-control" ]; then
        run ${lib.getExe pkgs.bun} install -g --trust @opencode-ai/browser-control
      fi
    '';

    # Sync the skill text from the installed CLI so skill and driver never
    # drift. Writes the canonical global location OpenCode reads natively
    # (~/.config/opencode/skills/...), then removes the one-off
    # `npx skills add -a opencode` copy in ~/.agents/skills so there is a
    # single source. Safe to re-run; OpenCode picks the managed copy up on
    # next start. If the CLI is missing, leave any existing skill alone.
    # NOTE: cli.js has a `#!/usr/bin/env node` shebang, but activation runs
    # with a minimal PATH, so put Nix's node first explicitly.
    home.activation.syncBrowserControlSkill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.nodejs}/bin:$PATH"
      if [ -x "$HOME/.bun/bin/browser-control" ]; then
        mkdir -p "$HOME/.config/opencode/skills/browser-control"
        "$HOME/.bun/bin/browser-control" skill > "$HOME/.config/opencode/skills/browser-control/SKILL.md"
        if [ -d "$HOME/.agents/skills/browser-control" ]; then
          rm -rf "$HOME/.agents/skills/browser-control"
        fi
      fi
    '';
  };
}
