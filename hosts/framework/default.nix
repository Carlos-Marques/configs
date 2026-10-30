# Framework Laptop 13 running NixOS + Hyprland. Install steps: README.md.
{
  pkgs,
  user,
  nixos-hardware,
  nixpkgs-master,
  ...
}:

let
  # nixos-hardware module for the mainboard. Match `lscpu | grep 'Model name'`:
  #   AMD Ryzen 5/7 7640U/7840U          -> framework-13-7040-amd
  #   AMD Ryzen AI 5 340 / AI 7 350 / AI 9 HX 370 -> framework-amd-ai-300-series
  #   Intel 11th Gen                     -> framework-11th-gen-intel
  #   Intel 12th Gen                     -> framework-12th-gen-intel
  #   Intel 13th Gen                     -> framework-13th-gen-intel
  #   Intel Core Ultra (Series 1, 1xxH)  -> framework-intel-core-ultra-series1
  #   Intel Core Ultra (Series 3, 3xx)   -> framework-intel-core-ultra-series3
  mainboard = "framework-amd-ai-300-series";
in
{
  imports = [
    nixos-hardware.nixosModules.${mainboard}
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "framework-machine-broke";

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    keep-derivations = true;
    keep-outputs = true;
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  boot = {
    # Secure Boot: lanzaboote installs systemd-boot itself and signs it and
    # every generation (kernel, initrd and command line in one image) with the
    # keys in /var/lib/sbctl. Setup steps: README.md.
    loader.efi.canTouchEfiVariables = true;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      # Keep the ESP from filling up with old kernels.
      configurationLimit = 20;
      # No editing the kernel command line from the boot menu.
      settings.editor = false;
    };

    # The TPM unlocks the disk, sealed to PCR 7 (Secure Boot on, with our
    # keys) and to PCR 15 still being empty; the passphrase stays enrolled as
    # the fallback. Enrolled once with systemd-cryptenroll (README.md).
    # tpm2-measure-pcr extends PCR 15 whenever a volume is unlocked, so the
    # TPM releases the key at most once per boot: code started from a
    # swapped-in fake root volume can't ask for it again.
    initrd.luks.devices.cryptroot.crypttabExtraOpts = [
      "tpm2-device=auto"
      "tpm2-measure-pcr=yes"
    ];
    # systemd-cryptsetup has systemd-pcrextend do that measurement, over its
    # socket. nixpkgs puts the socket in the initrd but nothing starts it
    # before the unlock, so the measurement failed ("Could not extend PCR: No
    # such file or directory"), cryptsetup carried on, and PCR 15 stayed
    # empty: the key stayed releasable after boot.
    initrd.systemd.services."systemd-cryptsetup@cryptroot" = {
      overrideStrategy = "asDropin";
      wants = [ "systemd-pcrextend.socket" ];
      after = [ "systemd-pcrextend.socket" ];
    };

    # Newest kernel: Framework hardware support lands upstream continuously.
    kernelPackages = pkgs.linuxPackages_latest;
    # Kernel errors (e.g. Framework's harmless "ucsi_acpi ... unknown error
    # 256") would otherwise print over tuigreet on tty1.
    consoleLogLevel = 3;
  };

  zramSwap.enable = true;

  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  # Firmware/BIOS updates via LVFS (`fwupdmgr update`).
  services.fwupd.enable = true;

  # Fingerprint reader: unlocks sudo, the greeter and hyprlock alongside the
  # password. Enroll with `fprintd-enroll` after the first login.
  services.fprintd.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # GUI apps; Ghostty comes from home-manager (programs.ghostty), Hyprland
  # from programs.hyprland below.
  environment.systemPackages = with pkgs; [
    brave
    # 2.8 for fingerprint Quick Unlock; see the file.
    (callPackage ./keepassxc.nix { })
    # Secure Boot keys and status (see boot.lanzaboote).
    sbctl
  ];

  # Chromium-family policy, same as the Mac's CustomUserPreferences: Brave reads
  # /etc/brave/policies/managed and force-installs KeePassXC-Browser.
  environment.etc."brave/policies/managed/keepassxc.json".text = builtins.toJSON {
    ExtensionInstallForcelist = [
      "oboonakemofpalcgghocfoadofidjkkk;https://clients2.google.com/service/update2/crx"
    ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  programs = {
    zsh.enable = true;

    # UWSM runs Hyprland as a systemd user session, so services that hang off
    # graphical-session.target (hypridle, waybar, mako) start and stop with it.
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    # Only for the PAM service; the lock screen itself is configured in
    # home/linux.nix.
    hyprlock.enable = true;
  };

  # xdg-open hands links to the desktop portal and returns at once. Without
  # it, xdg-open runs the browser in the foreground when it isn't already
  # open, so `netbird ssh` (which waits on xdg-open before listening for its
  # login callback) hung and the login page got "connection refused".
  xdg.portal.xdgOpenUsePortal = true;

  # No autologin: the TPM unlocks the disk without a prompt, so the greeter
  # (fingerprint or password) is what gates the machine.
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
  };

  # Personal NetBird mesh (NetBird Cloud). Log in once with
  # `sudo netbird up`; the client remembers the login.
  services.netbird = {
    enable = true;
    # Match the Mac, whose Homebrew tap ships releases the same day. 0.82.0 is
    # on nixpkgs master only; go back to pkgs.netbird once nixos-unstable has it.
    package = nixpkgs-master.legacyPackages.${pkgs.stdenv.hostPlatform.system}.netbird;
    # NetBird's own SSH server (Google login per session), so SSH is only
    # reachable through the mesh. Peers connect with plain `ssh`, which NetBird
    # redirects from 22 to 22022.
    clients.default.config.ServerSSHAllowed = true;
  };
  # No OpenSSH: NetBird SSH above is the only way in remotely.
  services.openssh.enable = false;

  # Default-deny inbound. Outside the mesh the only opening is NetBird's
  # WireGuard port (UDP 51820, from services.netbird's openFirewall). Traffic
  # inside the mesh (wt0) is filtered by NetBird's own ACL chains, which run
  # before these rules: access between peers is set by the NetBird
  # dashboard's policies, not here.
  networking.firewall = {
    enable = true;
    allowPing = false;
    # NetBird SSH, and Syncthing with the M4 (home/linux.nix).
    interfaces.wt0.allowedTCPPorts = [
      22022
      22000
    ];
  };

  # Mutable users: set the password with `passwd` during the install rather
  # than committing a hash to a public repo.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    shell = pkgs.zsh;
  };

  # Read the release notes before changing: it pins stateful defaults.
  system.stateVersion = "26.05";
}
