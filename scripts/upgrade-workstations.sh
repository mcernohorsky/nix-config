#!/usr/bin/env bash
# Update the T3 service, the Mac T3 app, and the Claude, Codex and OpenCode
# CLIs on both workstations.
#
#   (no args)  detach the job below and follow its log
#   --all      upgrade the other workstation, then this one
#   --host     upgrade only this machine
#
# Run from a T3 terminal, this script is a child of a T3 server that the
# upgrade restarts, so the real work runs outside that server's process tree.
set -euo pipefail

mac_host=macbook-pro-m2.tailc41cf5.ts.net
desktop_host=matt-desktop.tailc41cf5.ts.net
# T3 snapshots PATH when it installs its service; use the same stable set here.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export BUN_INSTALL="$HOME/.bun"

# Step functions run inside `if`, where errexit is off; chain with && instead.
failed=()
step() {
  local name=$1
  shift
  printf '\n==> %s\n' "$name"
  if ! "$@" </dev/null; then
    printf '!!! %s failed\n' "$name"
    failed+=("$name")
  fi
}

upgrade_opencode() {
  # Fall back to Bun when OpenCode's release service is unavailable.
  opencode upgrade --method bun || bun install -g --trust @opencode/cli@latest
}

upgrade_t3_service() {
  t3 update --channel nightly --yes || return
  if [ "$(uname)" = Linux ]; then
    systemctl --user reset-failed t3code.service || true
  fi
  t3 service install
}

stop_orphan_servers() {
  # T3's per-session OpenCode servers outlive T3 restarts as orphans of PID 1.
  pkill -P 1 -f 'opencode serve --hostname=' || true
}

# The Homebrew taps are pinned by the flake, so the cask lags nightlies; install
# the app release matching the service that `t3 update` just installed.
upgrade_mac_app() {
  local app="/Applications/T3 Code (Nightly).app" version current base zip tmp new pid sha
  version=$(t3 --version | sed 's/^t3 v//') || return
  current=$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)
  if [ "$current" = "$version" ]; then
    echo "App already on $version"
    return
  fi

  base="https://github.com/pingdotgg/t3code/releases/download/v$version"
  zip="T3-Code-$version-arm64.zip"
  tmp=$(mktemp -d) || return
  curl -fsSL -o "$tmp/$zip" "$base/$zip" &&
    sha=$(curl -fsSL "$base/nightly-mac.yml" | grep -A1 "url: $zip\$" | sed -n 's/^ *sha512: //p') &&
    [ -n "$sha" ] && [ "$(openssl dgst -sha512 -binary "$tmp/$zip" | base64)" = "$sha" ] &&
    ditto -x -k "$tmp/$zip" "$tmp/x" &&
    new=$(find "$tmp/x" -maxdepth 1 -name '*.app' | head -n 1) && [ -n "$new" ] ||
    { echo "Could not download and verify $zip" >&2; rm -rf "$tmp"; return 1; }

  # SIGTERM lets Electron quit cleanly, and needs no Automation permission.
  # The app name's parentheses would be regex groups to pgrep; match literally.
  pid=$(ps -axo pid=,command= | awk -v p="$app/Contents/MacOS/" \
    '{ pid = $1; sub(/^ *[0-9]+ /, "") } index($0, p) == 1 { print pid; exit }')
  if [ -n "$pid" ]; then
    echo "Quitting T3 Code"
    kill -TERM "$pid"
    for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid"
  fi
  # Copy first so a failed copy leaves the old app in place.
  rm -rf "$app.new"
  if ! { ditto "$new" "$app.new" && rm -rf "$app" && mv "$app.new" "$app"; }; then
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
  echo "App ${current:-missing} -> $version"
  [ -z "$pid" ] || open -a "$app"
}

upgrade_host() {
  step "Claude Code" claude update
  step "Codex" bun install -g @openai/codex@latest
  step "OpenCode" upgrade_opencode
  # After the CLIs, so the restarted service starts sessions on new versions.
  step "T3 service" upgrade_t3_service
  step "Stale OpenCode servers" stop_orphan_servers
  if [ "$(uname)" = Darwin ]; then
    step "T3 app" upgrade_mac_app
  fi
  if [ ${#failed[@]} -gt 0 ]; then
    printf '\n%s: failed: %s\n' "$(hostname -s)" "${failed[*]}"
    return 1
  fi
  printf '\n%s: done\n' "$(hostname -s)"
}

upgrade_all() {
  local self=$1 status=0 remote
  if [ "$(uname)" = Darwin ]; then
    remote=(tailscale ssh "matt@$desktop_host")
  else
    remote=(ssh "matt@$mac_host")
  fi
  # Send this script rather than relying on the other checkout being synced.
  # shellcheck disable=SC2016
  "${remote[@]}" 'f=$(mktemp) && cat >"$f" && bash "$f" --host </dev/null; s=$?; rm -f "$f"; exit $s' <"$self" ||
    status=1
  bash "$self" --host || status=1
  return "$status"
}

detach_and_follow() {
  local self=$1 dir="$HOME/.t3/userdata/logs" log done_file
  mkdir -p "$dir"
  log="$dir/upgrade-workstations.log"
  done_file="$log.status"
  rm -f "$done_file"
  : >"$log"
  # shellcheck disable=SC2016
  local job=(bash -c 'bash "$1" --all >>"$2" 2>&1; echo $? >"$3"' upgrade "$self" "$log" "$done_file")
  if [ "$(uname)" = Linux ]; then
    # systemd stops a service's whole cgroup, so leave T3's unit entirely.
    systemd-run --user --collect --quiet --unit="upgrade-workstations-$(date +%s)" \
      --setenv=SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" "${job[@]}"
  else
    # launchd kills the job's process group; a new session escapes it.
    perl -MPOSIX -e 'POSIX::setsid() or die "setsid: $!"; exec @ARGV' "${job[@]}" </dev/null >/dev/null 2>&1 &
  fi

  echo "Upgrading in the background; this terminal may close when T3 restarts."
  echo "Log: $log"
  tail -n +1 -f "$log" &
  local tail_pid=$!
  until [ -f "$done_file" ]; do sleep 1; done
  sleep 1
  kill "$tail_pid"
  exit "$(cat "$done_file")"
}

self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
case "${1:-}" in
  --host) upgrade_host ;;
  --all) upgrade_all "$self" ;;
  "") detach_and_follow "$self" ;;
  *)
    echo "usage: $0 [--all|--host]" >&2
    exit 2
    ;;
esac
