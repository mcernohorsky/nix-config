# `merge-json FILE FILTER`: apply a jq filter to an app-owned JSON settings
# file (`{}` when missing) and atomically replace it only if the result
# differs, so the app keeps its other settings and its file watcher sees no
# churn. A missing parent directory is created private.
{ pkgs }:
pkgs.writeShellApplication {
  name = "merge-json";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
  ];
  text = ''
    file=$1 filter=$2
    old='{}'
    if [ -e "$file" ]; then
      jq -e 'type == "object"' "$file" >/dev/null
      old=$(cat "$file")
    fi
    new=$(jq "$filter" <<<"$old")
    if [ "$(jq -S . <<<"$new")" = "$(jq -S . <<<"$old")" ]; then
      exit 0
    fi

    dir=$(dirname "$file")
    [ -d "$dir" ] || install -d -m 0700 "$dir"
    tmp=$(mktemp "$dir/.$(basename "$file").XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    printf '%s\n' "$new" >"$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$file"
  '';
}
