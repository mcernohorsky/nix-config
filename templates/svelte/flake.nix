{
  description = "Svelte development environment (TypeScript/Bun toolchain + Svelte LSP)";

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
        typescriptToolchain = with pkgs; [
          bun
          nodejs_22
          typescript
          nodePackages.typescript-language-server
          biome
          git
        ];
      in
      {
        # Same toolchain as templates/typescript — use when you only need TS/Bun tooling.
        devShells.typescript = pkgs.mkShell {
          buildInputs = typescriptToolchain;
          shellHook = ''
            echo "TypeScript-only dev shell (subset of this template)"
            echo "  bun: $(bun --version)"
            echo "  node: $(node --version)"
            echo "  tsc: $(tsc --version)"
          '';
        };

        # Superset: everything above + Svelte language server.
        devShells.default = pkgs.mkShell {
          buildInputs = typescriptToolchain ++ (with pkgs; [ nodePackages.svelte-language-server ]);
          shellHook = ''
            echo "Svelte dev shell (Bun-first + Node-backed language servers)"
            echo "  bun: $(bun --version)"
            echo "  node: $(node --version)"
            echo "  tsc: $(tsc --version)"
            echo ""
            echo "Use 'nix develop .#typescript' for the TS/Bun toolchain without Svelte LSP."
            echo ""
            echo "Quick start:"
            echo "  bun create svelte@latest my-app   # SvelteKit or Vite+Svelte"
            echo "  cd my-app && bun install"
          '';
        };
      }
    );
}
