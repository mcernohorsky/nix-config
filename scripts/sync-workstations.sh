#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
  "") check_only=false ;;
  --check) check_only=true ;;
  *) echo "Usage: just sync | just sync-check" >&2; exit 2 ;;
esac

case "$(uname -s)" in
  Darwin) peer=(tailscale ssh matt@matt-desktop.tailc41cf5.ts.net) ;;
  Linux) peer=(ssh matt@macbook-pro-m2.tailc41cf5.ts.net) ;;
  *) echo "Run this on the Mac or matt-desktop." >&2; exit 1 ;;
esac

local_changes=$(jj diff --from main --to @ --summary)
if [ -n "$local_changes" ]; then
  echo "Commit local changes and move main to the commit before syncing." >&2
  exit 1
fi

# Check the peer before publishing so an unfinished change is never replaced.
"${peer[@]}" 'cd ~/.config/nix-config && nix develop -c bash -s' <<'REMOTE_CHECK'
set -euo pipefail
peer_changes=$(jj diff --from main --to @ --summary)
if [ -n "$peer_changes" ]; then
  echo "The other workstation has unpublished working-copy changes. Combine them first." >&2
  exit 1
fi
peer_commits=$(jj log --no-graph -r 'main ~ ::main@origin' -T 'commit_id')
if [ -n "$peer_commits" ]; then
  echo "The other workstation has unpublished main commits. Combine them first." >&2
  exit 1
fi
REMOTE_CHECK

if "$check_only"; then
  echo "Both working copies match main; the peer has no unpublished commits."
  exit 0
fi

jj git push --remote origin --bookmark main
"${peer[@]}" 'cd ~/.config/nix-config && nix develop -c bash -s' <<'REMOTE_SYNC'
set -euo pipefail
jj git fetch --remote origin
# Fetch leaves the empty working-copy change at its old parent; move it to main.
peer_changes=$(jj diff --from @- --to @ --summary)
if [ -n "$peer_changes" ]; then
  echo "The peer working copy changed during sync. Its changes were preserved." >&2
  exit 1
fi
jj new main
peer_changes=$(jj diff --from main --to @ --summary)
test -z "$peer_changes"
REMOTE_SYNC

local_commit=$(jj log --no-graph -r main -T 'commit_id')
peer_commit=$("${peer[@]}" 'cd ~/.config/nix-config && nix develop -c jj log --no-graph -r main -T commit_id')
if [ "$local_commit" != "$peer_commit" ]; then
  echo "Sync verification failed: main differs between workstations." >&2
  exit 1
fi
local_changes=$(jj diff --from main --to @ --summary)
test -z "$local_changes"
echo "Both workstations are synced at $local_commit"
