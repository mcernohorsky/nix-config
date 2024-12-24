{
  description = "Go Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, gomod2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        gomod2nixPkgs = gomod2nix.legacyPackages.${system};
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "my-go-project";
          version = "0.1.0";
          pwd = ./.;
          src = ./.;
          modules = ./gomod2nix.toml;
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            go
            gopls
            delve
            go-tools
            gomod2nixPkgs.gomod2nix
          ];
        };
      });
}