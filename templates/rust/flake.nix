{
  description = "Rust development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      crane,
      flake-parts,
      nixpkgs,
      rust-overlay,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { system, lib, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };

          rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
          hasCargoToml = builtins.pathExists ./Cargo.toml;
          # Crane needs a lockfile to vendor deps; `cargo init` does not create one yet.
          hasCargoProject = hasCargoToml && builtins.pathExists ./Cargo.lock;
          src = craneLib.cleanCargoSource ./.;

          commonArgs = {
            inherit src;
            strictDeps = true;
            nativeBuildInputs = with pkgs; [ pkg-config ];
            buildInputs = lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
          };

          cargoArtifacts = if hasCargoProject then craneLib.buildDepsOnly commonArgs else null;
          package =
            if hasCargoProject then
              craneLib.buildPackage (
                commonArgs
                // {
                  inherit cargoArtifacts;
                  doCheck = false;
                }
              )
            else
              null;
        in
        {
          formatter = pkgs.nixfmt;

          packages = lib.optionalAttrs hasCargoProject {
            default = package;
            coverage = craneLib.cargoLlvmCov (
              commonArgs
              // {
                inherit cargoArtifacts;
                cargoLlvmCovExtraArgs = "--html";
              }
            );
          };

          checks = lib.optionalAttrs hasCargoProject {
            build = package;
            fmt = craneLib.cargoFmt { inherit src; };
            clippy = craneLib.cargoClippy (
              commonArgs
              // {
                inherit cargoArtifacts;
                cargoClippyExtraArgs = "--all-targets --all-features -- -D warnings";
              }
            );
            nextest = craneLib.cargoNextest (
              commonArgs
              // {
                inherit cargoArtifacts;
              }
            );
            doctests = craneLib.cargoDocTest (
              commonArgs
              // {
                inherit cargoArtifacts;
              }
            );
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = lib.optionals hasCargoProject [ package ];

            packages = with pkgs; [
              rustToolchain
              cargo-nextest
              cargo-llvm-cov
              cargo-deny
              bacon
              sccache
              nixd
              nixfmt
              git
            ];

            RUSTC_WRAPPER = "sccache";

            shellHook = ''
              export SCCACHE_DIR="''${HOME}/.cache/sccache"

              echo "Rust dev shell ready"
              echo "  rustc: $(rustc --version)"
              echo "  cargo: $(cargo --version)"
              echo ""
              echo "Checks:"
              echo "  cargo nextest run"
              echo "  cargo llvm-cov nextest --html"
              echo "  cargo deny check"
              echo "  nix flake check"
              ${lib.optionalString (!hasCargoToml) ''
                echo ""
                echo "Bootstrap the crate with: cargo init --vcs none --name $(basename "$PWD")"
              ''}
              ${lib.optionalString (hasCargoToml && !hasCargoProject) ''
                echo ""
                echo "Create Cargo.lock (e.g. cargo generate-lockfile or cargo build) so Nix/Crane can build the package and checks."
              ''}
            '';
          };
        };
    };
}
