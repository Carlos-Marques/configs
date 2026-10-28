# Placeholder until the install replaces it with the output of
# `nixos-generate-config --no-filesystems --show-hardware-config` on the
# laptop (filesystems come from disko.nix). These are the modules every
# Framework 13 needs to find its disk in the initrd.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
