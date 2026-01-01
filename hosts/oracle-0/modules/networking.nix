{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking = {
    # Enable systemd-networkd for proper container networking
    useNetworkd = true;
    useDHCP = false;
    networkmanager.enable = false;

    # NAT configuration for containers
    nat = {
      enable = true;
      internalInterfaces = [
        "br-containers"
        "ve-+"
      ];
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
        UseDNS = true; # Use Oracle's metadata service DNS
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
      addresses = [ { Address = "192.168.100.1/24"; } ];
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

  # Most important: do not restart networkd just because the unit changed.
  # This prevents SSH drops during activation.
  systemd.services.systemd-networkd.restartIfChanged = false;

  # DNS resolution
  services.resolved = {
    enable = true;
    fallbackDns = [
      "1.1.1.1"
      "1.0.0.1"
    ];
  };

  # Enable container hostname resolution via nss-mymachines
  system.nssModules = [ pkgs.systemd ];
  system.nssDatabases.hosts = lib.mkBefore [ "mymachines" ];
}
