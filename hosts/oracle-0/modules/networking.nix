_: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    networkmanager.enable = false;

    nat = {
      enable = true;
      internalInterfaces = [
        "br-containers"
        "ve-+"
      ];
      externalInterface = "enp0s6";
    };
  };

  systemd.network = {
    enable = true;

    # Main interface (Oracle Cloud). DHCP supplies addressing plus
    # Oracle's metadata-service DNS, routes, and domains (all defaults).
    networks."10-main" = {
      matchConfig.Name = "enp0s6";
      networkConfig = {
        DHCP = "ipv4";
        IPv4Forwarding = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    netdevs."20-br-containers".netdevConfig = {
      Kind = "bridge";
      Name = "br-containers";
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

    networks."30-container-ve" = {
      matchConfig.Name = "ve-* vb-*";
      networkConfig = {
        Bridge = "br-containers";
        IPv4Forwarding = true;
      };
    };
  };

  # Restarting networkd during activation drops the management connection.
  systemd.services.systemd-networkd.restartIfChanged = false;

  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [
      "1.1.1.1"
      "1.0.0.1"
    ];
  };
}
