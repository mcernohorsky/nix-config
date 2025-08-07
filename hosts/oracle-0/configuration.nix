{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    "${
      builtins.fetchTarball {
        url = "https://github.com/nix-community/disko/archive/v1.11.0.tar.gz";
        sha256 = "13brimg7z7k9y36n4jc1pssqyw94nd8qvgfjv53z66lv4xkhin92";
      }
    }/module.nix"
    ./disk-config.nix
    inputs.repertoire-builder.nixosModules.container
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd.systemd.enable = true;
  };

  systemd.targets.multi-user.enable = true;

  networking = {
    hostName = "oracle-0";
    # Enable systemd-networkd for proper container networking
    useNetworkd = true;
    useDHCP = false;
    networkmanager.enable = false;
    
    # NAT configuration for containers
    nat = {
      enable = true;
      internalInterfaces = [ "br-containers" "ve-+" ];
      externalInterface = "enp0s6";
    };
  };

  # systemd-networkd configuration
  systemd.network = {
    enable = true;
    
    # Main interface (Oracle Cloud)
    networks."10-main" = {
      matchConfig.Name = "enp0s6";
      networkConfig = {
        DHCP = "ipv4";
        IPv4Forwarding = true;
      };
      # Keep Oracle's DNS configuration from DHCP
      dhcpV4Config = {
        UseDNS = true;  # Use Oracle's metadata service DNS
        UseDomains = true;
        UseRoutes = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
    
    # Container bridge
    netdevs."20-br-containers" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "br-containers";
      };
    };
    
    networks."20-br-containers" = {
      matchConfig.Name = "br-containers";
      networkConfig = {
        IPv4Forwarding = true;
        IPMasquerade = "ipv4";
        DHCPServer = true;
      };
      addresses = [{ Address = "192.168.100.1/24"; }];
      dhcpServerConfig = {
        PoolOffset = 10;
        PoolSize = 100;
      };
    };
    
    # Container veth interfaces
    networks."30-container-ve" = {
      matchConfig.Name = "ve-* vb-*";
      networkConfig = {
        Bridge = "br-containers";
        IPv4Forwarding = true;
      };
    };
  };

  # DNS resolution
  services.resolved = {
    enable = true;
    fallbackDns = [ "1.1.1.1" "1.0.0.1" ];
  };

  # Enable container hostname resolution via nss-mymachines
  system.nssModules = [ pkgs.systemd ];
  system.nssDatabases.hosts = lib.mkBefore [ "mymachines" ];

  time.timeZone = "America/Edmonton";
  i18n.defaultLocale = "en_CA.UTF-8";

  users = {
    mutableUsers = false;
    users.matt = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca" ];
    };
  };

  # Enable passwordless sudo.
  security.sudo.extraRules = [
    {
      users = [ "matt" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    wget
    ghostty.terminfo
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.netdata = {
    enable = true;
    config = {
      web = {
        "bind to" = "unix:/run/netdata/netdata.sock 127.0.0.1:19999";
        "socket user" = "netdata";
        "socket group" = "netdata";
        "web files owner" = "root";
        "web files group" = "root";
      };
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts = {
      "cernohorsky.ca" = {
        extraConfig = ''
          respond "Matt's website will be here someday." 200
        '';
      };
      "stats.cernohorsky.ca" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:19999
        '';
      };
      "chess.cernohorsky.ca" = {
        extraConfig = ''
          reverse_proxy repertoire-builder:8090

          encode gzip

          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            X-Content-Type-Options "nosniff"
            X-Frame-Options "DENY"
            X-XSS-Protection "1; mode=block"
            Referrer-Policy "strict-origin-when-cross-origin"
          }
        '';
      };
    };
  };

  users.users.caddy.extraGroups = [ "netdata" ];

  # Configure nix for deployment
  nix.settings.trusted-users = [ "@wheel" ];

  # Disable autologin.
  services.getty.autologinUser = null;

  # Open ports in the firewall.
  networking.firewall = {
    allowedTCPPorts = [
      22
      80
      443
    ];
    trustedInterfaces = [ "br-containers" ];
  };

  # Additional container networking will be configured in repertoire-builder-container.nix

  # Disable documentation for minimal install.
  documentation.enable = false;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}
