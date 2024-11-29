{
  description = "Haskell development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # GHC and core tools
            ghc
            cabal-install
            stack
            haskell-language-server
            
            # Development tools
            hpack
            hlint
            ormolu
            
            # Common tools
            git
          ];

          shellHook = ''
            echo "λ Haskell development environment activated!"
            echo "Available tools:"
            echo "  - ghc: $(ghc --version)"
            echo "  - cabal: $(cabal --version)"
            echo "  - stack: $(stack --version)"
            echo "  - hls: Language server ready"
            echo "  - hlint: Linter ready"
            echo "  - ormolu: Formatter ready"
            echo ""
            echo "Quick start:"
            echo "  stack new my-project  # Create new project"
            echo "  stack build           # Build the project"
            echo "  stack test            # Run tests"
            echo "  stack ghci            # Start REPL"
            echo "  hlint .               # Lint code"
            echo "  ormolu -i src/**/*.hs # Format code"
          '';
        };
      });
}
