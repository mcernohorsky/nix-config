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

    # Deployment
    deploy-rs = {
      url = "github:serokell/deploy-rs";
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

    # Repertoire Builder (using HTTPS with token)
    repertoire-builder = {
      url = "git+ssh://git@github.com/mcernohorsky/repertoire-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI Coding Tools
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
  };

  outputs =
    { ... }@inputs:
    {
      darwinConfigurations.macbook-pro-m2 = inputs.darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          # System configuration
          ./hosts/macbook-pro-m2/configuration.nix

          # Home Manager configuration
          inputs.home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.matt.imports = [
                ./hosts/macbook-pro-m2/home/home.nix
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

      nixosConfigurations.oracle-0 = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/oracle-0/configuration.nix
        ];
      };

      # Deploy-rs configuration
      deploy.nodes.oracle-0 = {
        hostname = "161.153.41.243";
        sshUser = "matt";
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos inputs.self.nixosConfigurations.oracle-0;
        };
      };

      # Deploy-rs checks
      checks.aarch64-linux = inputs.deploy-rs.lib.aarch64-linux.deployChecks inputs.self.deploy;

      # Development shells
      devShells = inputs.nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" ] (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              inputs.deploy-rs.packages.${system}.deploy-rs
              just
              git
              ssh-to-age
            ];
            shellHook = ''
              echo "🚀 NixOS deployment environment ready!"
              echo "Use 'deploy .#oracle-0' to deploy to your Oracle VPS"
            '';
          };
        }
      );

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
