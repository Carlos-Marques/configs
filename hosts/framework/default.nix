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
    loader = {
      systemd-boot = {
        enable = true;
        # Keep the ESP from filling up with old kernels.
        configurationLimit = 20;
      };
      efi.canTouchEfiVariables = true;
    };
    # Newest kernel: Framework hardware support lands upstream continuously.
    kernelPackages = pkgs.linuxPackages_latest;
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
    keepassxc
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

  services.greetd = {
    enable = true;
    settings = {
      default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
      # Log straight in on boot: the LUKS passphrase already gates the machine.
      # Logging out falls back to tuigreet.
      initial_session = {
        command = "uwsm start hyprland-uwsm.desktop";
        inherit user;
      };
    };
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
  networking.firewall.interfaces.wt0.allowedTCPPorts = [ 22022 ];

  # Key-only SSH; the password is for the console, sudo and the lock screen.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
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
    # Same key as github.com/Carlos-Marques.keys (held in 1Password).
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICcullPbqhb88CocW8eYZOG3WUtbRC7q14CED/3DUNO/"
    ];
  };

  # Read the release notes before changing: it pins stateful defaults.
  system.stateVersion = "26.05";
}
