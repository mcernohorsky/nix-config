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
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" ];
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" ];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" ];
                    };
                    "@snapshots" = {
                      mountpoint = "/.snapshots";
                      mountOptions = [ "compress=zstd" ];
                    };
                    "@log" = {
                      mountpoint = "/var/log";
                      mountOptions = [ "compress=zstd" ];
                    };
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
