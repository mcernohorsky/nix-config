{
  description = "Typst development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            typst
            tinymist
            git
          ];

          shellHook = ''
            echo "Typst dev shell ready"
            echo "  typst: $(typst --version)"
            echo "  tinymist: LSP and formatting support ready"
            echo ""
            echo "Quick start:"
            echo "  typst compile main.typ"
            echo "  typst watch main.typ"
          '';
        };
      }
    );
}
