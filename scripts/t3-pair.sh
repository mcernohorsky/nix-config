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

# Pair with the T3 server on whichever workstation runs this.
exec "$HOME/.local/bin/t3" "${args[@]}"
