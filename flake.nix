{
  description = "nix-darwin and home-manager configuration by Matt Cernohorsky";

  inputs = {
    # Package sources
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Core system management
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Additional functionality
    ghostty.url = "github:clo4/ghostty-hm-module";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Homebrew taps
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
    aerospace-tap = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
  };
  
  outputs = { 
    self,
    nixpkgs,
    darwin,
    home-manager,
    ghostty,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    homebrew-bundle,
    aerospace-tap
  }: {
    darwinConfigurations.macbook-pro-m2 = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [ 
        # System configuration
        ./hosts/macbook-pro-m2/default.nix

        # Home Manager configuration
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.matt = { ... }: {
              imports = [
                ./home.nix
                ghostty.homeModules.default
              ];
            };
          };
        }

        # Homebrew configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "matt";
            mutableTaps = false;
            autoMigrate = true;

            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
              "homebrew/homebrew-bundle" = homebrew-bundle;
              "nikitabobko/homebrew-tap" = aerospace-tap;
            };
          };
        }
      ];
    };
  };
}
