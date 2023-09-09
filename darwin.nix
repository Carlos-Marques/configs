{ nix-darwin, home-manager, home }:

let
  darwinConfiguration = { pkgs, ... }: {
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    environment.systemPackages = [];

    # Auto upgrade nix package and the daemon service.
    services.nix-daemon.enable = true;
    # nix.package = pkgs.nix;

    # Necessary for using flakes on this system.
    nix.settings.experimental-features = "nix-command flakes";
    nix.settings.keep-derivations = true;
    nix.settings.keep-outputs = true;
    nix.settings.sandbox = false;

    # Create /etc/zshrc that loads the nix-darwin environment.
    programs.zsh.enable = true;  # default shell on catalina
    # programs.fish.enable = true;

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    system.stateVersion = 4;

    # The platform the configuration will be used on.
    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.config.allowUnfree = true;

    users.users.carlosmarques = {
      name = "carlosmarques";
      home = "/Users/carlosmarques";
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        cleanup = "zap";
        upgrade = true;
      };
      brews = [
        "openssl"
      ];
      casks = [
        "cursor"
        "brave-browser"
        "beekeeper-studio"
        "signal"
        "slack"
        "docker"
        "obsidian"
        "mqtt-explorer"
        "netbirdio/tap/netbird-ui"
      ];
    };
  };
in
nix-darwin.lib.darwinSystem {
  modules = [
    darwinConfiguration
    home-manager.darwinModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.users.carlosmarques = home;
    }
  ];
}