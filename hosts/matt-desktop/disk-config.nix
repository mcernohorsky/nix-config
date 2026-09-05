let
  # Shared by every Btrfs subvolume on the system disk.
  mountOptions = [
    "compress=zstd"
    "noatime"
  ];
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
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      inherit mountOptions;
                    };
                    "@home" = {
                      mountpoint = "/home";
                      inherit mountOptions;
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      inherit mountOptions;
                    };
                    "@snapshots" = {
                      mountpoint = "/.snapshots";
                      inherit mountOptions;
                    };
                    "@log" = {
                      mountpoint = "/var/log";
                      inherit mountOptions;
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
