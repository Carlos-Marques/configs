{ nix-darwin, home-manager, home, darwinVariables }:

let
  darwinConfiguration = { pkgs, ... }: {
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    environment.systemPackages = [ ];

    # Auto upgrade nix package and the daemon service.
    services = {
      nix-daemon = {
        enable = true;
      };

      # yabai = {
      #   enable = true;
      #   enableScriptingAddition = true;
      #   config = {
      #     external_bar = "off:40:0";
      #     menubar_opacity = 1.0;
      #     mouse_follows_focus = "off";
      #     focus_follows_mouse = "off";
      #     display_arrangement_order = "default";
      #     window_origin_display = "default";
      #     window_placement = "second_child";
      #     window_zoom_persist = "on";
      #     window_shadow = "on";
      #     window_animation_duration = 0.0;
      #     window_animation_easing = "ease_out_circ";
      #     window_opacity_duration = 0.0;
      #     active_window_opacity = 1.0;
      #     normal_window_opacity = 0.90;
      #     window_opacity = "off";
      #     insert_feedback_color = "0xffd75f5f";
      #     split_ratio = 0.50;
      #     split_type = "auto";
      #     auto_balance = "off";
      #     top_padding = 0;
      #     bottom_padding = 0;
      #     left_padding = 0;
      #     right_padding = 0;
      #     window_gap = 0;
      #     layout = "bsp";
      #     mouse_modifier = "fn";
      #     mouse_action1 = "move";
      #     mouse_action2 = "resize";
      #     mouse_drop_action = "swap";
      #   };

      # };

      skhd = {
        enable = true;
        skhdConfig = ''
          # Move window left
          shift + ctrl - h : yabai -m window --warp west

          # Move window down
          shift + ctrl - j : yabai -m window --warp south

          # Move window up
          shift + ctrl - k : yabai -m window --warp north

          # Move window right
          shift + ctrl - l : yabai -m window --warp east

          # Focus window left
          ctrl - h : yabai -m window --focus west

          # Focus window down
          ctrl - j : yabai -m window --focus south

          # Focus window up
          ctrl - k : yabai -m window --focus north

          # Focus window right
          ctrl - l : yabai -m window --focus east
          
          # create desktop, move window and follow focus - uses jq for parsing json
          shift + ctrl - n : yabai -m space --create && \
            index="$$(yabai -m query --spaces --display | jq 'map(select(."is-native-fullscreen" == false))[-1].index')" && \
            yabai -m window --space "$${index}" && \
            yabai -m space --focus "$${index}"
            
          # destroy desktop
          shift + ctrl - d : yabai -m space --destroy
          
          # focus desktop
          ctrl - 1 : yabai -m space --focus 1
          ctrl - 2 : yabai -m space --focus 2
          ctrl - 3 : yabai -m space --focus 3
          
          # move window to desktop and focus
          shift + ctrl - 1 : yabai -m window --space 1; yabai -m space --focus 1
          shift + ctrl - 2 : yabai -m window --space 2; yabai -m space --focus 2
          shift + ctrl - 3 : yabai -m window --space 3; yabai -m space --focus 3
          
          # toggle fullscreen
          ctrl - f : yabai -m window --toggle zoom-fullscreen
        '';
      };
    };
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
    programs.zsh.enable = true; # default shell on catalina

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    system = {
      stateVersion = 4;
      keyboard = {
        enableKeyMapping = true;
      };
    };

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
      taps = [
        "depot/tap"
      ];
      brews = [
        "openssl"
        "netbirdio/tap/netbird"
        "depot/tap/depot"
      ];
      casks = [
        "chatgpt"
        "tableplus"
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
