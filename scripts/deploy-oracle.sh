#!/usr/bin/env bash
# Build oracle-0's aarch64 closure natively: on the Mac's Linux builder when
# the Mac is reachable, otherwise on oracle-0 at idle priority.
set -euo pipefail

cd "$(dirname "$0")/.."

mac=matt@macbook-pro-m2.tailc41cf5.ts.net
deploy=(nix run .#deploy-rs -- .#oracle-0 --skip-checks)

if [ "$(uname -s)" = Darwin ]; then
  exec "${deploy[@]}"
fi

if ssh -o ConnectTimeout=5 -o BatchMode=yes "$mac" true 2>/dev/null; then
  echo "Building on the Mac"
  # Evaluate here so uncommitted changes and private inputs need no checkout
  # on the Mac. Once the closure is local, deploy-rs has nothing to build.
  drv=$(nix eval --raw .#deploy.nodes.oracle-0.profiles.system.path.drvPath)
  out=$(nix build --no-link --print-out-paths --eval-store auto --store "ssh-ng://$mac" "$drv^*")
  nix copy --no-check-sigs --from "ssh-ng://$mac" "$out"
  exec "${deploy[@]}"
fi

echo "The Mac is unreachable; building on oracle-0"
exec "${deploy[@]}" --remote-build
