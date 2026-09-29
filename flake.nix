{
  description = "nix-darwin and home-manager configuration by Matt Cernohorsky";

  # Binary caches used by this flake's builds and deploys.
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
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # Oracle is a semi-production server: keep it on the small stable channel.
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
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Upstream's own nixpkgs pin generates crates.io URLs the ARM builder rejects.
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
    hex-homebrew-tap = {
      url = "github:anomalyco/homebrew-tap";
      flake = false;
    };
    tinycast-homebrew-tap = {
      url = "github:abue-ammar/homebrew-tinycast";
      flake = false;
    };
    sonora-homebrew-tap = {
      url = "github:nolight132/homebrew-tap";
      flake = false;
    };

    # Applications
    helix-master.url = "github:helix-editor/helix";
    nordwand-mono = {
      url = "github:tywr/Nordwand-Mono";
      flake = false;
    };
    # Pins its own nixpkgs (bun-sensitive webDist hash).
    repertoire-builder.url = "git+ssh://git@github.com/mcernohorsky/repertoire-builder";
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # HEX voice dictation, Linux beta only; macOS uses the Homebrew tap.
    # Pinned: 2.1.20 (e579625) fails to build voice-control on Linux (E0432).
    hex = {
      url = "github:anomalyco/hex?rev=9a11b5fc7209ab04b9ae22a06d9ff153cffe4777";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

      # Shared by every host: local packages and Home Manager wiring.
      common = {
        nixpkgs.overlays = [ inputs.self.overlays.default ];
      };
      homeManager = users: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
          users.matt.imports = [ ./modules/home ] ++ users;
        };
      };
      nixosModules = [
        common
        inputs.determinate.nixosModules.default
        inputs.agenix.nixosModules.default
        inputs.disko.nixosModules.disko
        ./modules/nixos/common.nix
      ];
    in
    {
      darwinConfigurations.macbook-pro-m2 = inputs.darwin.lib.darwinSystem {
        specialArgs = { inherit inputs; };
        modules = [
          common
          inputs.determinate.darwinModules.default
          inputs.agenix.darwinModules.default
          inputs.home-manager.darwinModules.home-manager
          inputs.nix-homebrew.darwinModules.nix-homebrew
          ./hosts/macbook-pro-m2/configuration.nix
          (homeManager [ ./hosts/macbook-pro-m2/home/home.nix ])
        ];
      };

      nixosConfigurations.oracle-0 = inputs.nixpkgs-server.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = nixosModules ++ [ ./hosts/oracle-0/configuration.nix ];
      };

      nixosConfigurations.matt-desktop = lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = nixosModules ++ [
          inputs.home-manager.nixosModules.home-manager
          ./hosts/matt-desktop/configuration.nix
          (homeManager [
            ./hosts/matt-desktop/home.nix
            inputs.cosmic-manager.homeManagerModules.default
            inputs.hex.homeManagerModules.hex
          ])
        ];
      };

      # Activation restarts networking while Tailscale is the only SSH path,
      # so deploy-rs cannot confirm a switch even when it succeeds; magic
      # rollback would undo every deploy.
      deploy = {
        sshUser = "matt";
        user = "root";
        magicRollback = false;
        nodes.oracle-0 = {
          hostname = "oracle-0.tailc41cf5.ts.net";
          profiles.system.path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos inputs.self.nixosConfigurations.oracle-0;
        };
        nodes.matt-desktop = {
          hostname = "matt-desktop.tailc41cf5.ts.net";
          remoteBuild = true;
          profiles.system.path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.matt-desktop;
        };
      };

      overlays.default = final: _prev: {
        nordwand-mono = final.callPackage ./packages/nordwand-mono.nix { src = inputs.nordwand-mono; };
        runebender = final.callPackage ./packages/runebender.nix { };
      };

      packages = forSystems (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;
        in
        lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) {
          inherit (pkgs) nordwand-mono runebender;
        }
      );

      # `nix run .#deploy-rs -- .#oracle-0`
      apps = forSystems (system: {
        deploy-rs = {
          type = "app";
          program = "${inputs.deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
        };
      });

      checks = lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (
        system: inputs.deploy-rs.lib.${system}.deployChecks inputs.self.deploy
      );

      formatter = forSystems (system: inputs.nixpkgs.legacyPackages.${system}.nixfmt-tree);

      devShells = forSystems (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              inputs.deploy-rs.packages.${system}.deploy-rs
              inputs.agenix.packages.${system}.default
              pkgs.just
              pkgs.ssh-to-age
            ];
          };
        }
      );

      templates = import ./templates;
    };
}
