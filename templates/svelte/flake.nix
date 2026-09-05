{
  description = "Svelte development environment (TypeScript/Bun toolchain + Svelte LSP)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        typescriptToolchain = with pkgs; [
          bun
          nodejs
          typescript
          nodePackages.typescript-language-server
          biome
          git
        ];
      in
      {
        # Same toolchain as templates/typescript — use when you only need TS/Bun tooling.
        devShells.typescript = pkgs.mkShell {
          packages = typescriptToolchain;
        };

        # Superset: everything above + Svelte language server.
        devShells.default = pkgs.mkShell {
          packages = typescriptToolchain ++ (with pkgs; [ nodePackages.svelte-language-server ]);
        };
      }
    );
}
