{
  description = "nix-darwin and home-manager configuration by Matt Cernohorsky";

  # Binary caches for faster builds (applies during nix build/deploy)
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://deploy-rs.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
    ];
  };

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
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Deployment (don't override nixpkgs - use upstream's pinned version for cache hits)
    deploy-rs.url = "github:serokell/deploy-rs";

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

    # Repertoire Builder (using HTTPS with token)
    repertoire-builder = {
      url = "git+ssh://git@github.com/mcernohorsky/repertoire-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI Coding Tools
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Secrets management
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop-specific inputs
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
          inputs.agenix.nixosModules.default
          ./hosts/oracle-0/configuration.nix
        ];
      };

      nixosConfigurations.matt-desktop = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          inputs.agenix.nixosModules.default
          inputs.disko.nixosModules.disko
          inputs.stylix.nixosModules.stylix
          inputs.home-manager.nixosModules.home-manager
          ./hosts/matt-desktop/configuration.nix
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.matt = import ./hosts/matt-desktop/home.nix;
            };
          }
        ];
      };

      # Deploy-rs configuration (using Tailscale MagicDNS hostnames)
      deploy.nodes.oracle-0 = {
        hostname = "oracle-0.tailc41cf5.ts.net";
        sshUser = "matt";
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos inputs.self.nixosConfigurations.oracle-0;
        };
      };

      deploy.nodes.matt-desktop = {
        hostname = "matt-desktop.tailc41cf5.ts.net";
        sshUser = "matt";
        remoteBuild = true;
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.matt-desktop;
        };
      };

      # Deploy-rs checks
      checks.aarch64-linux = inputs.deploy-rs.lib.aarch64-linux.deployChecks inputs.self.deploy;
      checks.x86_64-linux = inputs.deploy-rs.lib.x86_64-linux.deployChecks inputs.self.deploy;

      # Development shells
      devShells = inputs.nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" ] (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              deploy-rs
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
