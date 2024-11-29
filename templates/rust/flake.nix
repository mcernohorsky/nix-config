{
  description = "Rust development environment";

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
            # Rust tools
            rustc
            cargo
            rust-analyzer
            clippy
            rustfmt
            
            # Common tools
            git
          ];

          shellHook = ''
            echo "🦀 Rust development environment activated!"
            echo "Available tools:"
            echo "  - rustc: $(rustc --version)"
            echo "  - cargo: $(cargo --version)"
            echo "  - rust-analyzer: Language server ready"
            echo "  - clippy: Linter ready"
            echo "  - rustfmt: Formatter ready"
            echo ""
            echo "Quick start:"
            echo "  cargo new my-project  # Create new binary project"
            echo "  cargo new --lib my-lib # Create new library"
            echo "  cargo build           # Build the project"
            echo "  cargo test            # Run tests"
            echo "  cargo clippy          # Run linter"
          '';
        };
      });
}
