{
  description = "Typst proposal project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fontPaths = "${pkgs.inter}/share/fonts";
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              git
              just
              tinymist
              typst
              typstyle
            ];

            TYPST_FONT_PATHS = fontPaths;

            shellHook = ''
              echo "Typst proposal shell"
              echo "  typst: $(typst --version)"
              echo ""
              echo "Commands:"
              echo "  just build"
              echo "  just watch"
              echo "  just format"
            '';
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.nixfmt-tree
      );

      checks = forAllSystems (system: {
        proposal = self.packages.${system}.default;
      });

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fontPaths = "${pkgs.inter}/share/fonts";
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "typst-proposal";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.typst ];
            TYPST_FONT_PATHS = fontPaths;
            dontConfigure = true;
            buildPhase = ''
              typst compile main.typ proposal.pdf
            '';
            installPhase = ''
              install -Dm0644 proposal.pdf "$out/proposal.pdf"
            '';
          };
        }
      );
    };
}
