{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.tailscalePolicy;

  # Manages the tailnet policy file through the Tailscale API using the
  # policy_file-scoped OAuth client in agenix
  # (secrets/tailscale-policy-oauth.age, owner matt on both agent hosts).
  # A short-lived API token is minted per invocation; the client secret
  # never leaves the agenix file and is never printed. `apply` sends the
  # live ETag back as If-Match, so a concurrent console edit fails loudly
  # instead of being silently overwritten.
  tailscale-policy = pkgs.writeShellApplication {
    name = "tailscale-policy";
    runtimeInputs = [
      pkgs.curl
      pkgs.python3
      pkgs.diffutils
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      creds_file="''${TAILSCALE_POLICY_CREDENTIALS:-/run/agenix/tailscale-policy-oauth}"
      api="https://api.tailscale.com/api/v2/tailnet/-/acl"

      usage() {
        echo "usage: tailscale-policy <show|diff <file>|apply <file> [--yes]>" >&2
        exit 2
      }

      mint_token() {
        if [ ! -f "$creds_file" ]; then
          echo "tailscale-policy: credentials not found at $creds_file" >&2
          exit 1
        fi
        client_id="$(sed -n 's/^TS_API_CLIENT_ID=//p' "$creds_file")"
        client_secret="$(sed -n 's/^TS_API_CLIENT_SECRET=//p' "$creds_file")"
        if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
          echo "tailscale-policy: malformed credentials at $creds_file" >&2
          exit 1
        fi
        curl -fsS --max-time 20 \
          -d "client_id=$client_id" -d "client_secret=$client_secret" \
          https://api.tailscale.com/api/v2/oauth/token |
          python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])'
      }

      cmd="''${1:-}"
      if [ $# -gt 0 ]; then shift; fi
      case "$cmd" in
        show) ;;
        diff | apply)
          file="''${1:-}"
          if [ -z "$file" ]; then usage; fi
          if [ ! -f "$file" ]; then
            echo "tailscale-policy: no such file: $file" >&2
            exit 1
          fi
          ;;
        *) usage ;;
      esac
      assume_yes=0
      if [ "''${2:-}" = "--yes" ]; then assume_yes=1; fi

      tmp_remote="$(mktemp)"
      tmp_headers="$(mktemp)"
      tmp_resp="$(mktemp)"
      trap 'rm -f "$tmp_remote" "$tmp_headers" "$tmp_resp"' EXIT

      token="$(mint_token)"

      # Fetches the live policy into $tmp_remote and its ETag into
      # $remote_etag. Refuses to continue without an ETag: applying blind
      # could clobber a concurrent edit.
      fetch_remote() {
        curl -fsS --max-time 20 -D "$tmp_headers" -o "$tmp_remote" \
          -H "Authorization: Bearer $token" "$api"
        remote_etag="$(grep -i '^etag:' "$tmp_headers" | tr -d '\r' | awk '{print $2}')"
        if [ -z "$remote_etag" ]; then
          echo "tailscale-policy: GET response had no ETag, refusing to continue" >&2
          exit 1
        fi
      }

      case "$cmd" in
        show)
          fetch_remote
          cat "$tmp_remote"
          ;;
        diff)
          fetch_remote
          diff -u "$tmp_remote" "$file"
          ;;
        apply)
          fetch_remote
          if cmp -s "$tmp_remote" "$file"; then
            echo "tailscale-policy: already in sync, nothing to apply"
            exit 0
          fi
          diff -u "$tmp_remote" "$file" || true
          if [ "$assume_yes" != "1" ]; then
            printf 'Apply this policy? Type YES to confirm: '
            read -r reply
            if [ "$reply" != "YES" ]; then
              echo "tailscale-policy: aborted"
              exit 1
            fi
          fi
          if ! curl --fail-with-body --max-time 30 -X POST \
            -H "Authorization: Bearer $token" \
            -H "If-Match: $remote_etag" \
            -H "Content-Type: application/hujson" \
            --data-binary "@$file" "$api" -o "$tmp_resp"; then
            echo "tailscale-policy: apply rejected:" >&2
            cat "$tmp_resp" >&2
            exit 1
          fi
          echo "tailscale-policy: applied"
          ;;
      esac
    '';
  };
in
{
  options.modules.home.tailscalePolicy.enable = lib.mkEnableOption "Tailscale policy-file API helper";

  config = lib.mkIf cfg.enable {
    home.packages = [ tailscale-policy ];
  };
}
