{
  description = "nix-darwin and home-manager configuration by Matt Cernohorsky";

  # Binary caches for faster builds (applies during nix build/deploy)
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://deploy-rs.cachix.org"
      "https://cache.flakehub.com"
      "https://install.determinate.systems"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # Oracle is a semi-production headless server: keep it on the supported
    # small stable channel while desktop experimentation stays on unstable.
    nixpkgs-server.url = "github:NixOS/nixpkgs/nixos-26.05-small";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
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

    # Deploy-rs must resolve against the same nixpkgs as the targets.
    # Its upstream pin generates obsolete crates.io fetch URLs that the
    # native ARM builder rejects.
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

    # Additional packages
    helix-master.url = "github:helix-editor/helix";
    nordwand-mono = {
      url = "github:tywr/Nordwand-Mono";
      flake = false;
    };

    # Repertoire Builder pins its own nixpkgs (bun-sensitive webDist hash).
    # Preserve the release already live on Oracle (verified 2026-09-17).
    repertoire-builder.url = "git+ssh://git@github.com/mcernohorsky/repertoire-builder?rev=9db8eaf7b3d9e9367af440af708993c00ba91a39";

    # Secrets management
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager/1630bbf792a95baffbd3169885580cd53a7027d8";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # HEX voice dictation. Its flake packages the Linux beta (x86_64-linux
    # only); macOS installs from its Homebrew tap instead (see nix-homebrew
    # taps below and homebrew.casks on the Mac host).
    hex = {
      url = "github:anomalyco/hex";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    hex-homebrew-tap = {
      url = "github:anomalyco/homebrew-tap";
      flake = false;
    };

  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;
      forSystems = lib.genAttrs [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-linux"
      ];
    in
    {
      darwinConfigurations.macbook-pro-m2 = inputs.darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          # Determinate nix-darwin compatibility module
          inputs.determinate.darwinModules.default
          inputs.agenix.darwinModules.default

          # System configuration
          ./hosts/macbook-pro-m2/configuration.nix

          # Home Manager configuration
          inputs.home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.matt.imports = [ ./hosts/macbook-pro-m2/home/home.nix ];
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
                "anomalyco/homebrew-tap" = inputs.hex-homebrew-tap;
              };
              # Third-party taps need an explicit trust entry for their casks.
              trust = {
                casks = [ "anomalyco/tap/hex" ];
              };
            };
          }
        ];
      };

      nixosConfigurations.oracle-0 = inputs.nixpkgs-server.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          inputs.determinate.nixosModules.default
          inputs.agenix.nixosModules.default
          ./hosts/oracle-0/configuration.nix
        ];
      };

      nixosConfigurations.matt-desktop = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          inputs.determinate.nixosModules.default
          inputs.agenix.nixosModules.default
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          ./hosts/matt-desktop/configuration.nix
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.matt = {
                imports = [
                  ./hosts/matt-desktop/home.nix
                  inputs.cosmic-manager.homeManagerModules.default
                  inputs.hex.homeManagerModules.hex
                ];
              };
            };
          }
        ];
      };

      # Deploy-rs configuration (using Tailscale MagicDNS hostnames).
      # sshUser/magicRollback are top-level deploy-rs defaults inherited by
      # every node: activation restarts networking while Tailscale is the
      # only SSH path, so deploy-rs cannot confirm the switch even when it
      # succeeds. Verify manually with e.g. `just verify-chess` after deploy.
      deploy = {
        sshUser = "matt";
        magicRollback = false;
        nodes.oracle-0 = {
          hostname = "oracle-0.tailc41cf5.ts.net";
          profiles.system = {
            user = "root";
            path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos inputs.self.nixosConfigurations.oracle-0;
          };
        };
        nodes.matt-desktop = {
          hostname = "matt-desktop.tailc41cf5.ts.net";
          remoteBuild = true;
          profiles.system = {
            user = "root";
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.matt-desktop;
          };
        };
      };

      # Expose deploy-rs as a runnable flake app:
      #   nix run .#deploy-rs -- --skip-checks .#oracle-0
      apps = forSystems (system: {
        deploy-rs = {
          type = "app";
          program = "${inputs.deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
        };
      });

      # Deploy-rs checks (Linux targets only)
      checks = lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (
        system: inputs.deploy-rs.lib.${system}.deployChecks inputs.self.deploy
      );

      # Development shells
      devShells = forSystems (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              inputs.deploy-rs.packages.${system}.deploy-rs
              pkgs.just
              pkgs.git
              pkgs.ssh-to-age
              inputs.agenix.packages.${system}.default
            ];
          };
        }
      );

      templates = import ./templates;
    };
}
