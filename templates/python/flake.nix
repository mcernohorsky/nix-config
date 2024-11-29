{
  description = "Python development environment";

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
            # Python and core tools
            python311
            python311Packages.pip
            python311Packages.virtualenv
            poetry
            ruff
            black
            
            # Language server and debugging
            python311Packages.python-lsp-server
            python311Packages.debugpy
            
            # Common tools
            git
          ];

          shellHook = ''
            echo "🐍 Python development environment activated!"
            echo "Available tools:"
            echo "  - python: $(python --version)"
            echo "  - pip: $(pip --version)"
            echo "  - poetry: $(poetry --version)"
            echo "  - ruff: Linter ready"
            echo "  - black: Formatter ready"
            echo "  - python-lsp-server: Language server ready"
            echo ""
            echo "Quick start:"
            echo "  poetry new my-project  # Create new project"
            echo "  poetry add package     # Add dependency"
            echo "  poetry install         # Install dependencies"
            echo "  poetry run python      # Run Python"
            echo "  black .                # Format code"
            echo "  ruff check .           # Lint code"
          '';
        };
      });
}
