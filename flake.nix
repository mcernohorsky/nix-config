{
  description = "nix-darwin and home-manager configuration by Matt Cernohorsky";

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    # Additional packages
    helix-master.url = "github:helix-editor/helix";
    # ghostty.url = "github:clo4/ghostty-hm-module";
  };

  outputs =
    { ... }@inputs:
    {
      darwinConfigurations.macbook-pro-m2 = inputs.darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          # System configuration
          ./hosts/macbook-pro-m2/default.nix

          # Home Manager configuration
          inputs.home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.matt.imports = [
                ./home.nix
                # inputs.ghostty.homeModules.default
              ];
            };
          }

          # Homebrew configuration
          inputs.nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "matt";
              mutableTaps = false;
              autoMigrate = true;
              taps = {
                "homebrew/homebrew-core" = inputs.homebrew-core;
                "homebrew/homebrew-cask" = inputs.homebrew-cask;
                "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
              };
            };
          }
        ];
      };

      templates = {
        zig = {
          path = ./templates/zig;
          description = "Zig development environment";
        };
        go = {
          path = ./templates/go;
          description = "Go development environment";
        };
        rust = {
          path = ./templates/rust;
          description = "Rust development environment";
        };
        python = {
          path = ./templates/python;
          description = "Python development environment";
        };
        haskell = {
          path = ./templates/haskell;
          description = "Haskell development environment";
        };
        typst = {
          path = ./templates/typst;
          description = "Typst development environment";
        };
        react-native = {
          path = ./templates/react-native;
          description = "React Native development environment";
        };
      };
    };
}
