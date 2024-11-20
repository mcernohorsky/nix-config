{
  description = "nix-darwin and home-manager configuration by Matt Cernohorsky";

  inputs = {
    # Core dependencies
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    
    # System management
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # User environment management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Additional modules
    ghostty.url = "github:clo4/ghostty-hm-module";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Optional: Declarative tap management
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
  
  outputs = { self, nixpkgs, darwin, home-manager, ghostty, nix-homebrew, homebrew-core, homebrew-cask, homebrew-bundle, aerospace-tap }: {
    darwinConfigurations.macbook-pro-m2 = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [ 
        ./hosts/macbook-pro-m2/default.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.matt = { ... }: {
            imports = [
              ./home.nix
              ghostty.homeModules.default
            ];
          };
        }
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;

            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = true;

            # User owning the Homebrew prefix
            user = "matt";

            # Optional: Declarative tap management
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
              "homebrew/homebrew-bundle" = homebrew-bundle;
              "nikitabobko/homebrew-tap" = aerospace-tap;
            };

            # Optional: Enable fully-declarative tap management
            #
            # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
            mutableTaps = false;

            # Automatically migrate existing Homebrew installations
            autoMigrate = true;
          };
        }
      ];
    };
  };
}
