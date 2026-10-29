{ pkgs, user, ... }:

{
  # GUI apps go here rather than home.packages: nix-darwin copies them into
  # /Applications/Nix Apps as real bundles, which Spotlight indexes. Home
  # Manager only symlinks them, and Spotlight ignores symlinked apps.
  environment.systemPackages = [ pkgs.ghostty-bin ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      keep-derivations = true;
      keep-outputs = true;
      sandbox = true;
      trusted-users = [
        "root"
        "@admin"
      ];
    };

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 14d";
    };
    optimise.automatic = true;

    linux-builder = {
      enable = true;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      maxJobs = 4;
      # NOTE: `config` customizes the builder's NixOS image, which must be built
      # *on* a Linux builder. If no builder is running (fresh machine, or the
      # builder generation was lost), comment this out, switch once with the
      # default cached image, then restore it and switch again.
      config = {
        boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
        # Use QEMU's NAT DNS proxy - 10.0.2.3 forwards to host's DNS
        networking.nameservers = [ "10.0.2.3" ];
        # nixpkgs' qemu-common.nix hardcodes `gic-version=2` for HVF, which
        # QEMU >= 11.1 rejects ("HVF does not support GICv2 emulation").
        # Repeated -machine options are merged, so this overrides it.
        virtualisation.qemu.options = [
          "-machine"
          "gic-version=3"
        ];
      };
    };
  };

  # Keep in sync with the nixbld group created by the Nix installer.
  ids.gids.nixbld = 350;

  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  time.timeZone = "America/Los_Angeles";

  # Hostname is intentionally not managed here: Kandji MDM owns it.
  networking.knownNetworkServices = [
    "Wi-Fi"
    "Ethernet"
  ];

  system = {
    primaryUser = user;
    # Read the changelog before changing: $ darwin-rebuild changelog
    stateVersion = 4;
    keyboard.enableKeyMapping = true;
    defaults = {
      # Chromium reads user-level `defaults` as browser policy. Force-install
      # KeePassXC-Browser so the extension follows the config; Brave shows it as
      # "installed by your administrator" and won't let it be removed by hand.
      CustomUserPreferences."com.brave.Browser".ExtensionInstallForcelist = [
        "oboonakemofpalcgghocfoadofidjkkk;https://clients2.google.com/service/update2/crx"
      ];
      # System Settings' "Correct spelling automatically" toggle writes both keys;
      # nix-darwin only has an option for the native one, the Web one covers WebKit.
      CustomUserPreferences.NSGlobalDomain.WebAutomaticSpellingCorrectionEnabled = false;
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };
      trackpad.Clicking = true;
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

  services.aerospace = {
    enable = true;
    settings = {
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      # KeePassXC's unlock / access dialogs pop up on Touch ID requests from
      # Brave and the CLI; floating keeps them from being tiled into the layout.
      on-window-detected = [
        {
          "if".app-id = "org.keepassxc.keepassxc";
          run = "layout floating";
        }
      ];

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
        "alt-s" = "layout accordion horizontal vertical";
        "alt-t" = "layout tiles horizontal vertical";

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

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
    # Homebrew 6 refuses to install from non-official taps unless trusted.
    taps = [
      {
        name = "depot/tap";
        trusted = true;
      }
      {
        name = "flyteorg/tap";
        trusted = true;
      }
      {
        name = "netbirdio/tap";
        trusted = true;
      }
      {
        name = "peak/tap";
        trusted = true;
      }
    ];
    brews = [
      "openssl"
      "depot/tap/depot"
      "flyteorg/tap/flytectl"
      "netbirdio/tap/netbird"
      "peak/tap/s5cmd"
    ];
    casks = [
      "1password"
      "beekeeper-studio"
      "block-buzz"
      "brave-browser"
      "chatgpt"
      "claude"
      "claude-code"
      "cursor"
      "docker-desktop"
      # Not "gemini": that cask is MacPaw's duplicate-file finder.
      "google-gemini"
      # Cask, not nixpkgs: Touch ID quick unlock stores the key in the Keychain,
      # which macOS only allows for Apple-signed binaries. Vault layout and the
      # GUI settings that can't be declared are in README.md.
      "keepassxc"
      "mqtt-explorer"
      "mullvad-vpn"
      "netbirdio/tap/netbird-ui"
      "qbittorrent"
      "scoot"
      "signal"
      "slack"
      "tableplus"
      "vlc"
      "wispr-flow"
    ];
  };
}
