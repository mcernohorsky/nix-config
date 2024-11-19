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
  };
  
  outputs = { self, nixpkgs, darwin, home-manager, ghostty }: {
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
      ];
    };
  };
}
