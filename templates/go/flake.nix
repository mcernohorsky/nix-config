{
  description = "Go development environment";

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
          GOTOOLCHAIN = "local";

          packages = with pkgs; [
            go_latest
            gopls
            gotools
            golangci-lint
            delve
            git
          ];
        };
      }
    );
}
