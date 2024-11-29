{
  description = "Go development environment";

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
            # Go tools
            go
            gopls
            golangci-lint
            delve
            go-tools
            
            # Common tools
            git
          ];

          nativeBuildInputs = with pkgs; lib.optionals stdenv.isDarwin [
            darwin.apple_sdk.frameworks.Security
            darwin.apple_sdk.frameworks.SystemConfiguration
          ];

          shellHook = ''
            echo "🦫 Go development environment activated!"
            echo "Available tools:"
            echo "  - go: $(go version)"
            echo "  - gopls: Language server ready"
            echo "  - golangci-lint: $(golangci-lint --version)"
            echo "  - delve: Debugger ready"
            echo ""
            echo "Quick start:"
            echo "  go mod init my-project"
            echo "  go mod tidy"
            echo "  go run ."
            echo "  go test ./..."
          '';
        };
      });
}
