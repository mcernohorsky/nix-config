#!/usr/bin/env bash
set -euo pipefail

# --scope replaces T3's defaults, so include every grantable scope.
scopes=(
  orchestration:read orchestration:operate settings:write providers:manage
  environment:maintain preview:operate diagnostics:read terminal:read
  terminal:operate source-control:write filesystem:read filesystem:write
  relay:read access:read access:write relay:write
)
args=(pair --tailscale --ttl 5m --label full-access-client)
for scope in "${scopes[@]}"; do
  args+=(--scope "$scope")
done

case "${1:-}" in
  mac)
    if [ "$(uname -s)" = Darwin ]; then
      exec "$HOME/.local/bin/t3" "${args[@]}"
    fi
    peer=(ssh matt@macbook-pro-m2.tailc41cf5.ts.net)
    ;;
  desktop) peer=(tailscale ssh matt@matt-desktop.tailc41cf5.ts.net) ;;
  *) echo 'Usage: just t3-pair-full mac|desktop' >&2; exit 2 ;;
esac

printf -v remote_args ' %q' "${args[@]}"
exec "${peer[@]}" '"$HOME/.local/bin/t3"'"$remote_args"
