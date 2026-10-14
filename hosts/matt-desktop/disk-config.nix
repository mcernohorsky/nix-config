let
  subvolume = mountpoint: {
    inherit mountpoint;
    mountOptions = [
      "compress=zstd"
      "noatime"
    ];
  };
in
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_24371J800693";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                content = {
                  type = "btrfs";
                  subvolumes = builtins.mapAttrs (_: subvolume) {
                    "@root" = "/";
                    "@home" = "/home";
                    "@nix" = "/nix";
                    "@snapshots" = "/.snapshots";
                    "@log" = "/var/log";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
