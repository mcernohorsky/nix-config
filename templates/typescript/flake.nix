{
  description = "TypeScript development environment (Bun-first)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bun
            nodejs
            typescript
            nodePackages.typescript-language-server
            biome
            git
          ];

          shellHook = ''
            echo "TypeScript dev shell (Bun-first + Node for LSP/npm compatibility)"
            echo "  bun: $(bun --version)"
            echo "  node: $(node --version)"
            echo "  tsc: $(tsc --version)"
            echo ""
            echo "Quick start:"
            echo "  bun init                    # new project"
            echo "  bun add -d typescript       # add TypeScript"
            echo "  bunx tsc --init             # tsconfig.json"
            echo "  biome init                  # formatter/linter config"
          '';
        };
      }
    );
}
