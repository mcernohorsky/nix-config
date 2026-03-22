{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.devTemplates;
  templates = import ../../templates;
  supportedLanguages = builtins.attrNames templates;
  supportedLanguagesString = lib.concatStringsSep " " supportedLanguages;
  devCommand = pkgs.writeShellApplication {
    name = "dev";
    runtimeInputs = with pkgs; [
      nix
      direnv
      coreutils
      git
    ];
    text = ''
                  set -euo pipefail

                  supported_languages="${supportedLanguagesString}"
                  repo_path="$HOME/.config/nix-config"

                  usage() {
                    printf 'Usage: dev <language> [directory]\n' >&2
                    printf 'Supported languages: %s\n' "$supported_languages" >&2
                    exit 1
                  }

                  is_supported_language() {
                    local candidate="$1"
                    local language

                    for language in $supported_languages; do
                      if [ "$language" = "$candidate" ]; then
                        return 0
                      fi
                    done

                    return 1
                  }

                  ensure_empty_dir() {
                    local dir="$1"
                    local entries=()

                    shopt -s dotglob nullglob
                    entries=("$dir"/*)
                    shopt -u dotglob nullglob

                    if [ "''${#entries[@]}" -ne 0 ]; then
                      printf 'Error: target directory is not empty: %s\n' "$dir" >&2
                      exit 1
                    fi
                  }

                  default_go_module() {
                    local project="$1"
                    local github_user

                    github_user="$(git config --global --get github.user 2>/dev/null || true)"

                    if [ -n "$github_user" ]; then
                      printf 'github.com/%s/%s\n' "$github_user" "$project"
                    else
                      printf '%s\n' "$project"
                    fi
                  }

                  if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
                    usage
                  fi

                  language="$1"
                  target_input="''${2:-.}"

                  if ! is_supported_language "$language"; then
                    printf 'Error: unsupported language %s\n' "$language" >&2
                    usage
                  fi

                  if [ ! -d "$repo_path" ]; then
                    printf 'Error: nix-config repo not found at %s\n' "$repo_path" >&2
                    exit 1
                  fi

                  case "$target_input" in
                    .)
                      target_dir="$PWD"
                      ;;
                    /*)
                      target_dir="$target_input"
                      ;;
                    *)
                      target_dir="$PWD/$target_input"
                      ;;
                  esac

                  project_name="$(basename "$target_dir")"

                  mkdir -p "$target_dir"
                  ensure_empty_dir "$target_dir"

                  (
                    cd "$target_dir"
        nix flake init -t "path:$repo_path#$language"

                    case "$language" in
                      rust)
                        nix develop --accept-flake-config -c cargo init --vcs none --name "$project_name"
                        ;;
                      python)
                        nix develop --accept-flake-config -c uv init --vcs none --name "$project_name" --no-python-downloads
                        ;;
                      go)
                        module_path="$(default_go_module "$project_name")"
                        nix develop --accept-flake-config -c go mod init "$module_path"
                        cat > main.go <<EOF
            package main

            import "fmt"

      func main() {
      	fmt.Println("hello from ''${project_name}")
      }
      EOF
                        nix develop --accept-flake-config -c go fmt ./...
                        ;;
                      svelte)
                        nix develop --accept-flake-config -c bunx sv create . --template minimal --types ts --no-add-ons --install bun --no-dir-check
                        ;;
                      typescript)
                        nix develop --accept-flake-config -c bun init --yes
                        ;;
                    esac

                    if [ -f .envrc ]; then
                      direnv allow || true
                    fi
                  )

                  printf 'Initialized %s project in %s\n' "$language" "$target_dir"
    '';
  };
in
{
  options.modules.home.devTemplates.enable =
    lib.mkEnableOption "shared dev/template bootstrap command";

  config = lib.mkIf cfg.enable {
    home.packages = [ devCommand ];
  };
}
