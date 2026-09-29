{
  services.taildrive.shares = {
    ssd = "/";
    hdd = "/mnt/hdd";
  };

  # Samba over the direct ethernet link to the MacBook (link-local only).
  # "bind interfaces only" is unusable: smbd crashes if enp4s0 is missing.
  services.samba = {
    enable = true;
    nmbd.enable = false; # Avahi handles macOS discovery
    winbindd.enable = false;
    settings = {
      global = {
        "hosts allow" = "169.254. fe80::/10";
        "hosts deny" = "ALL";
      };
      root = {
        path = "/";
        browseable = "yes";
        "read only" = "no";
        "force user" = "matt";
      };
    };
  };
  networking.firewall.interfaces.enp4s0.allowedTCPPorts = [ 445 ];

  # mDNS for Finder discovery, restricted to the direct link.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    allowInterfaces = [ "enp4s0" ];
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles.smb = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
      </service-group>
    '';
  };
}
