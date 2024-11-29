{
  description = "Typst development environment";

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
            # Typst and core tools
            typst
            typst-lsp
            typst-fmt
            
            # PDF tools
            zathura
            
            # Common tools
            git
          ];

          shellHook = ''
            echo "📝 Typst development environment activated!"
            echo "Available tools:"
            echo "  - typst: $(typst --version)"
            echo "  - typst-lsp: Language server ready"
            echo "  - typst-fmt: Formatter ready"
            echo "  - zathura: PDF viewer ready"
            echo ""
            echo "Quick start:"
            echo "  typst compile doc.typ    # Compile to PDF"
            echo "  typst watch doc.typ      # Watch and compile"
            echo "  typst-fmt doc.typ        # Format document"
            echo ""
            echo "Example doc.typ:"
            echo '#set document(title: "My Document")'
            echo '#set text(font: "New Computer Modern")'
            echo ''
            echo '= Hello, Typst!'
            echo ''
            echo 'Your content here.'
          '';
        };
      });
}
