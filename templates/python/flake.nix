{
  description = "Python development environment (uv-first)";

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
            python313
            uv
            ruff
            basedpyright
            python313Packages.debugpy
            nixd
            nixfmt
            git
          ];

          UV_PYTHON_DOWNLOADS = "never";

          shellHook = ''
            echo "Python dev shell (uv + ruff + basedpyright)"
            echo "  python: $(python --version)"
            echo "  uv: $(uv --version)"
            echo "  ruff: $(ruff --version)"
            echo ""
            echo "Quick start:"
            echo "  uv init --no-python-downloads"
            echo "  uv add ruff pytest         # add deps"
            echo "  uv run pytest              # run tests"
            echo "  uv run ruff check .        # lint"
            echo "  uv run ruff format .       # format"
          '';
        };
      }
    );
}
