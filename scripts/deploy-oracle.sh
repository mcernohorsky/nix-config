#!/usr/bin/env bash
# Deploy oracle-0, building its aarch64 closure on oracle-0 (at idle priority),
# the Mac (native Linux builder) or the desktop (emulated).
set -euo pipefail

cd "$(dirname "$0")/.."

deploy=(nix run .#deploy-rs -- .#oracle-0 --skip-checks)

case "${1:-oracle}" in
  oracle) exec "${deploy[@]}" --remote-build ;;
  mac) builder=macbook-pro-m2 local_os=Darwin ;;
  desktop) builder=matt-desktop local_os=Linux ;;
  *) echo "Usage: just deploy-oracle [oracle|mac|desktop]" >&2; exit 2 ;;
esac

if [ "$(uname -s)" != "$local_os" ]; then
  # Evaluate here so the builder needs no checkout and builds uncommitted
  # changes. Once the closure is local, deploy-rs has nothing left to build.
  store="ssh-ng://matt@$builder.tailc41cf5.ts.net"
  drv=$(nix eval --raw .#deploy.nodes.oracle-0.profiles.system.path.drvPath)
  out=$(nix build --no-link --print-out-paths --eval-store auto --store "$store" "$drv^*")
  nix copy --no-check-sigs --from "$store" "$out"
fi

exec "${deploy[@]}"
