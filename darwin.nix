{
  nix-darwin,
  home-manager,
  home,
  darwinVariables,
}:

let
  darwinConfiguration =
    { pkgs, lib, ... }:
    {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [ ];

      # Auto upgrade nix package and the daemon service.
      services = {
        aerospace = {
          enable = true;
          settings = {
            on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

            mode.main.binding = {
              "alt-h" = "focus --boundaries-action wrap-around-the-workspace left";
              "alt-j" = "focus --boundaries-action wrap-around-the-workspace down";
              "alt-k" = "focus --boundaries-action wrap-around-the-workspace up";
              "alt-l" = "focus --boundaries-action wrap-around-the-workspace right";

              "alt-shift-h" = "move left";
              "alt-shift-j" = "move down";
              "alt-shift-k" = "move up";
              "alt-shift-l" = "move right";

              "alt-f" = "fullscreen";

              "alt-1" = "workspace 1";
              "alt-2" = "workspace 2";
              "alt-3" = "workspace 3";
              "alt-4" = "workspace 4";
              "alt-shift-1" = "move-node-to-workspace 1";
              "alt-shift-2" = "move-node-to-workspace 2";
              "alt-shift-3" = "move-node-to-workspace 3";
              "alt-shift-4" = "move-node-to-workspace 4";

              "alt-q" = "workspace Q";
              "alt-w" = "workspace W";
              "alt-e" = "workspace E";
              "alt-r" = "workspace R";
              "alt-shift-q" = "move-node-to-workspace Q";
              "alt-shift-w" = "move-node-to-workspace W";
              "alt-shift-e" = "move-node-to-workspace E";
              "alt-shift-r" = "move-node-to-workspace R";

              "alt-period" = "focus-monitor next";
              "alt-comma" = "focus-monitor prev";
            };
            workspace-to-monitor-force-assignment = {
              "1" = "secondary";
              "2" = "secondary";
              "3" = "secondary";
              "4" = "secondary";
              "Q" = "primary";
              "W" = "primary";
              "E" = "primary";
              "R" = "primary";
            };
          };
        };
      };

      # Necessary for using flakes on this system.
      nix = {
        settings = {
          experimental-features = "nix-command flakes";
          keep-derivations = true;
          keep-outputs = true;
          sandbox = true;
          trusted-users = [
            "root"
            "carlosmarques"
            "@admin"
          ];
        };

        linux-builder = {
          enable = true;
          systems = [
            "x86_64-linux"
            "aarch64-linux"
          ];
          maxJobs = 4;
          config = {
            boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
            # Use QEMU's NAT DNS proxy - 10.0.2.3 forwards to host's DNS
            networking.nameservers = [ "10.0.2.3" ];
          };
        };
      };

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true; # default shell on catalina

      security.pam.services.sudo_local.touchIdAuth = true;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system = {
        primaryUser = "carlosmarques";
        stateVersion = 4;
        keyboard = {
          enableKeyMapping = true;
        };
        defaults = {
          NSGlobalDomain = {
            ApplePressAndHoldEnabled = false;
          };
          trackpad = {
            Clicking = true;
          };
          magicmouse.MouseButtonMode = "TwoButton";
          dock = {
            autohide = true;
            mru-spaces = false;
            orientation = "left";
            show-recents = false;
            tilesize = 36;
            persistent-apps = [ ];
            persistent-others = [ ];
            wvous-bl-corner = 1;
            wvous-br-corner = 1;
            wvous-tl-corner = 1;
            wvous-tr-corner = 1;
          };
        };
      };

      time.timeZone = "America/Los_Angeles";

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = darwinVariables.hostPlatform;
      nixpkgs.config.allowUnfree = true;

      networking = {
        knownNetworkServices = [
          "Wi-Fi"
          "Ethernet"
        ];
        # dns = [ "1.1.1.1" "1.0.0.1" ];
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
        taps = [
          "depot/tap"
          "netbirdio/tap"
          "flyteorg/homebrew-tap"
          "nikitabobko/tap"
          "peak/tap"
        ];
        brews = [
          "openssl"
          "netbirdio/tap/netbird"
          "depot/tap/depot"
          "flyteorg/homebrew-tap/flytectl"
          "peak/tap/s5cmd"
        ];
        casks = [
          "nikitabobko/tap/aerospace"
          "keepassxc"
          "1password"
          "chatgpt"
          "tableplus"
          "cursor"
          "brave-browser"
          "beekeeper-studio"
          "signal"
          "slack"
          "docker-desktop"
          "obsidian"
          "mqtt-explorer"
          "netbirdio/tap/netbird-ui"
          "scoot"
          "qbittorrent"
          "mullvad-vpn"
          "vlc"
        ];
      };

      ids.gids.nixbld = 350;
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
