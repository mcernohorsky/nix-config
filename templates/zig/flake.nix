{
  description = "Zig development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig = {
      url = "github:silversquirl/zig-flake/compat";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-overlay.follows = "zig";
    };
  };

  outputs =
    {
      flake-utils,
      nixpkgs,
      zig,
      zls,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShellNoCC {
          packages = [
            zig.packages.${system}.nightly
            zls.packages.${system}.zls
            pkgs.git
          ];

          shellHook = ''
            echo "Zig dev shell ready"
            echo "  zig: $(zig version)"
            echo "  zls: ready"
            echo ""
            echo "Quick start:"
            echo "  zig init"
            echo "  zig build"
            echo "  zig test src/root.zig"
          '';
        };
      }
    );
}
