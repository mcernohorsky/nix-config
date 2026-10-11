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

# Run locally when pairing with this machine, otherwise on the named peer.
case "${1:-}" in
  mac) local_os=Darwin peer=(ssh matt@macbook-pro-m2.tailc41cf5.ts.net) ;;
  desktop) local_os=Linux peer=(tailscale ssh matt@matt-desktop.tailc41cf5.ts.net) ;;
  *) echo 'Usage: t3-pair.sh mac|desktop' >&2; exit 2 ;;
esac

if [ "$(uname -s)" = "$local_os" ]; then
  exec "$HOME/.local/bin/t3" "${args[@]}"
fi
printf -v remote_args ' %q' "${args[@]}"
# shellcheck disable=SC2016 # $HOME expands on the peer
exec "${peer[@]}" '"$HOME/.local/bin/t3"'"$remote_args"
