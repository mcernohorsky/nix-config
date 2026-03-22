{
  description = "Haskell development environment";

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
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            ghc
            cabal-install
            haskell-language-server
            ghcid
            hlint
            fourmolu
            git
          ];

          shellHook = ''
            echo "Haskell dev shell ready"
            echo "  ghc: $(ghc --version)"
            echo "  cabal: $(cabal --version | head -n1)"
            echo ""
            echo "Quick start:"
            echo "  cabal init"
            echo "  cabal build"
            echo "  cabal test"
            echo "  ghcid --command \"cabal repl\""
          '';
        };
      }
    );
}
