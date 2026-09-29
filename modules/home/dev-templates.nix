# `dev <language> [directory]`: initialize a project from ../../templates.
{ lib, pkgs, ... }:
let
  languages = lib.concatStringsSep " " (builtins.attrNames (import ../../templates));

  devCommand = pkgs.writeShellApplication {
    name = "dev";
    # Omit pkgs.nix so it cannot shadow Determinate Nix on PATH.
    runtimeInputs = with pkgs; [
      direnv
      coreutils
      git
    ];
    text = ''
      repo="$HOME/.config/nix-config"
      languages="${languages}"

      usage() {
        printf 'Usage: dev <language> [directory]\nSupported languages: %s\n' "$languages" >&2
        exit 1
      }

      [ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
      language="$1"
      case " $languages " in
        *" $language "*) ;;
        *) usage ;;
      esac
      [ -d "$repo" ] || { printf 'Error: nix-config repo not found at %s\n' "$repo" >&2; exit 1; }

      target="$(realpath -m -- "''${2:-.}")"
      name="$(basename "$target")"
      mkdir -p "$target"
      if [ -n "$(ls -A "$target")" ]; then
        printf 'Error: target directory is not empty: %s\n' "$target" >&2
        exit 1
      fi

      cd "$target"
      nix flake init -t "path:$repo#$language"
      run() { nix develop --accept-flake-config -c "$@"; }
      case "$language" in
        rust) run cargo init --vcs none --name "$name" ;;
        python) run uv init --vcs none --name "$name" --no-python-downloads ;;
        go)
          github_user="$(git config --global --get github.user || true)"
          run go mod init "''${github_user:+github.com/$github_user/}$name"
          printf 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("hello from %s")\n}\n' "$name" > main.go
          ;;
        svelte) run bunx sv create . --template minimal --types ts --no-add-ons --install bun --no-dir-check ;;
        typescript) run bun init --yes ;;
      esac

      if [ -f .envrc ] && ! direnv allow; then
        printf 'Warning: direnv allow failed; run it manually in %s\n' "$target" >&2
      fi
      printf 'Initialized %s project in %s\n' "$language" "$target"
    '';
  };
in
{
  home.packages = [ devCommand ];
}
