# Declarative partitioning, applied once from the installer with disko (see
# README.md). Wipes `device`.
#
# ESP + LUKS2 holding btrfs subvolumes. Swap is zram (default.nix), so there's
# no swap partition; hibernation isn't set up.
{
  disko.devices.disk.main = {
    type = "disk";
    # Check with `lsblk` from the installer before applying.
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # No passwordFile: disko prompts for the passphrase at install time,
            # so it never touches the repo or the Nix store.
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes =
                let
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                in
                {
                  "/root" = {
                    mountpoint = "/";
                    inherit mountOptions;
                  };
                  "/home" = {
                    mountpoint = "/home";
                    inherit mountOptions;
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    inherit mountOptions;
                  };
                };
            };
          };
        };
      };
    };
  };
}
