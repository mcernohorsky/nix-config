{
  description = "Zig development environment";

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
        devShells.default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            zig
            zls
            git
          ];

          shellHook = ''
            echo "Zig dev shell ready"
            echo "  - zig: $(zig version)"
            echo "  - zls: Language server ready"
            echo ""
            echo "Quick start:"
            echo "  zig init-exe    # For an executable"
            echo "  zig init-lib    # For a library"
            echo "  zig build       # Build the project"
            echo "  zig build test  # Run tests"
          '';
        };
      }
    );
}
