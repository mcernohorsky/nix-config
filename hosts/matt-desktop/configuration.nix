{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config.allowUnfree = true;

  users.users.matt = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca" ];
  };

  omarchy = {
    full_name = "Matt Cernohorsky";
    email_address = "matt@cernohorsky.ca";
    theme = "gruvbox";
    exclude_packages = with pkgs; [
      vscode
    ];
  };

  home-manager = {
    users.matt = {
      imports = [ inputs.omarchy-nix.homeManagerModules.default ];
      home.stateVersion = "25.05";
      nixpkgs.config.allowUnfree = true;
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Set to false since we have the key working!
      PermitRootLogin = "prohibit-password";
    };
  };

  services.tailscale.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";
}
