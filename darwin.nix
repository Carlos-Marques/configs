{ nix-darwin, home-manager, home, darwinVariables }:

let
  darwinConfiguration = { pkgs, ... }: {
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    environment.systemPackages = [];

    # Auto upgrade nix package and the daemon service.
    services.nix-daemon.enable = true;
    # nix.package = pkgs.nix;

    # Necessary for using flakes on this system.
    nix = {
      settings = {
        experimental-features = "nix-command flakes";
        keep-derivations = true;
        keep-outputs = true;
        sandbox = false;
      };
    };

    # Create /etc/zshrc that loads the nix-darwin environment.
    programs.zsh.enable = true;  # default shell on catalina

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    system.stateVersion = 4;

    # The platform the configuration will be used on.
    nixpkgs.hostPlatform = darwinVariables.hostPlatform;
    nixpkgs.config.allowUnfree = true;
    
    networking = {
      dns = [ "1.1.1.1" "1.0.0.1" ];
    };

    users.users."${darwinVariables.user}" = {
      name = darwinVariables.user;
      home = darwinVariables.homePath;
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
        "scoot"
      ];
    };
  };
in
nix-darwin.lib.darwinSystem {
  modules = [
    darwinConfiguration
    home-manager.darwinModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        users.carlosmarques = home;
      };
    }
  ];
}