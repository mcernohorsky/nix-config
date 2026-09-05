{
  description = "Python development environment (uv-first)";

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
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python314
            uv
            ruff
            basedpyright
            python314Packages.debugpy
            nixd
            nixfmt
            git
          ];

          # The global Python is managed by uv, but project environments use
          # only the interpreter supplied by this pinned Nix dev shell.
          UV_NO_MANAGED_PYTHON = "1";
          UV_PYTHON_DOWNLOADS = "never";
        };
      }
    );
}
