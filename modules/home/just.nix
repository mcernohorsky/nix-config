# A global `just` (outside dev shells too), and `just-to-t3` to list a repo's
# recipes in T3's scripts menu via a checked-in t3.json.
{ config, pkgs, ... }:
let
  justToT3 = pkgs.writeShellApplication {
    name = "just-to-t3";
    runtimeInputs = with pkgs; [
      coreutils
      git
      jq
      just
    ];
    text = ''
      # T3 runs scripts at the repo root, so read the justfile from there too.
      root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
      cd "$root"

      # A T3 terminal may run the command before nushell's direnv hook fires,
      # so enter the dev shell explicitly when the repo has one.
      prefix="just "
      [ -f .envrc ] && prefix="direnv exec . just "

      old='{}'
      [ -f t3.json ] && old=$(cat t3.json)

      tmp=$(mktemp t3.json.XXXXXX)
      trap 'rm -f "$tmp"' EXIT
      # T3 scripts take no arguments, so recipes with required parameters are
      # skipped. Edits to generated entries (icon, runOnWorktreeCreate, …) and
      # scripts that don't call just are kept.
      jq -n \
        --argjson dump "$(just --dump --dump-format json)" \
        --arg order "$(just --summary --unsorted)" \
        --arg prefix "$prefix" \
        --argjson old "$old" '
        def icon:
          if test("(^|-)test") then "test"
          elif test("(^|-)(lint|fmt|format|check|clippy)") then "lint"
          elif test("(^|-)(build|deploy|release)") then "build"
          elif test("(^|-)(setup|install|init|configure)") then "configure"
          elif test("(^|-)(debug|logs?)") then "debug"
          else "play" end;
        ($old.scripts // []) as $prev
        | [ $order | split(" ")[]
            | select(. != "" and . != "default" and (contains("::") | not))
            | $dump.recipes[.]
            | select(. != null and (.private | not))
            | select(all(.parameters[]; .default != null or .kind == "star"))
            | .name as $n
            | ($prev | map(select(.name == $n)) | first // {}) as $p
            | {name: $n, command: ($prefix + $n), icon: ($n | icon)} + ($p | del(.name, .command))
          ] as $generated
        | ($prev | map(select(.command | test("^(direnv exec \\. )?just ") | not))) as $kept
        | {"$schema": "https://t3.codes/schema/t3.json"} + $old
          + {scripts: ($generated + $kept)}
      ' > "$tmp"

      count=$(jq '.scripts | length' "$tmp")
      if [ "$count" -gt 50 ]; then
        printf 'just-to-t3: %s scripts; T3 accepts at most 50\n' "$count" >&2
        exit 1
      fi
      mv "$tmp" t3.json
      trap - EXIT
      printf 'Wrote %s scripts to %s/t3.json\n' "$count" "$root"
    '';
  };
in
{
  home.packages = [
    pkgs.just
    justToT3
  ];

  # T3 checks out each thread's worktree under ~/.t3/worktrees; trust their
  # .envrc like the main checkout's so `direnv exec` scripts work there too.
  programs.direnv.config.whitelist.prefix = [ "${config.home.homeDirectory}/.t3/worktrees" ];
}
