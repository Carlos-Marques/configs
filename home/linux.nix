# Home Manager config for NixOS machines (Hyprland); shared settings are in
# default.nix.
{ pkgs, ... }:

let
  terminal = "uwsm app -- ghostty";
  lock = "pidof hyprlock || hyprlock";
in
{
  home.packages = with pkgs; [
    brightnessctl
    grim
    playerctl
    slurp
    wl-clipboard
  ];

  # See darwin.nix; this one starts at the release the machine was installed on.
  home.stateVersion = "26.05";

  programs.zsh.shellAliases.rebuild = "sudo nixos-rebuild switch --flake ~/configs";

  # The M4 Mac, reached only at its NetBird address; see darwin.nix.
  services.syncthing.settings = {
    devices.m4-machine-broke = {
      id = "LEDDOU4-6WTRH53-EYXATVE-JL2I63A-SLPSAQB-FQ5LENN-QEKXYDF-HTQT6QK";
      addresses = [ "tcp://100.111.48.21:22000" ];
    };
    folders."~/vault".devices = [ "m4-machine-broke" ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    # Both come from the NixOS module (programs.hyprland), and UWSM owns the
    # systemd session, so home-manager only writes hyprland.conf.
    package = null;
    portalPackage = null;
    systemd.enable = false;
    # Hyprland 0.56 reads either hyprland.lua (the default for stateVersion
    # 26.05) or the classic hyprland.conf. These settings use the classic
    # syntax; the Lua API is a different shape (hl.bind("SUPER + Q", ...)).
    configType = "hyprlang";

    # https://wiki.hypr.land/Configuring/Variables/
    settings = {
      monitor = ",preferred,auto,auto";

      input = {
        kb_layout = "us";
        # Mac-like trackpad: natural scrolling, tap to click.
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
        };
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        layout = "dwindle";
      };

      # Three-finger swipe between workspaces.
      gesture = "3, horizontal, workspace";

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      # KeePassXC at login on the vault; it remembers the key file from the
      # last unlock, so only the master password is typed. Later unlocks take
      # the fingerprint (Quick Unlock, hosts/framework/keepassxc.nix). Not
      # --keyfile: with it KeePassXC tries to unlock straight away with an
      # empty password and fails.
      exec-once = [ "uwsm app -- keepassxc ~/vault/vault.kdbx" ];

      # Same keys as AeroSpace in darwin.nix (Alt as the modifier); Super takes
      # the Mac's Cmd shortcuts.
      bind = [
        "ALT, h, movefocus, l"
        "ALT, j, movefocus, d"
        "ALT, k, movefocus, u"
        "ALT, l, movefocus, r"

        "ALT SHIFT, h, movewindow, l"
        "ALT SHIFT, j, movewindow, d"
        "ALT SHIFT, k, movewindow, u"
        "ALT SHIFT, l, movewindow, r"

        "ALT, f, fullscreen"
        # AeroSpace's accordion / tiles toggles: tab the window into a group,
        # or flip the split direction.
        "ALT, s, togglegroup"
        "ALT, t, layoutmsg, togglesplit"

        "ALT, 1, workspace, 1"
        "ALT, 2, workspace, 2"
        "ALT, 3, workspace, 3"
        "ALT, 4, workspace, 4"
        "ALT SHIFT, 1, movetoworkspace, 1"
        "ALT SHIFT, 2, movetoworkspace, 2"
        "ALT SHIFT, 3, movetoworkspace, 3"
        "ALT SHIFT, 4, movetoworkspace, 4"

        "ALT, q, workspace, name:Q"
        "ALT, w, workspace, name:W"
        "ALT, e, workspace, name:E"
        "ALT, r, workspace, name:R"
        "ALT SHIFT, q, movetoworkspace, name:Q"
        "ALT SHIFT, w, movetoworkspace, name:W"
        "ALT SHIFT, e, movetoworkspace, name:E"
        "ALT SHIFT, r, movetoworkspace, name:R"

        "ALT, period, focusmonitor, +1"
        "ALT, comma, focusmonitor, -1"

        "SUPER, Return, exec, ${terminal}"
        "SUPER, space, exec, fuzzel"
        "SUPER, q, killactive"
        # ⌃⌘Q / ⇧⌘4 / ⇧⌘3 on the Mac.
        "SUPER CTRL, q, exec, loginctl lock-session"
        ''SUPER SHIFT, 4, exec, grim -g "$(slurp)" - | wl-copy''
        "SUPER SHIFT, 3, exec, grim - | wl-copy"
        "SUPER SHIFT, Escape, exec, uwsm stop"
      ];

      # Drag with Alt held: left button moves, right button resizes.
      bindm = [
        "ALT, mouse:272, movewindow"
        "ALT, mouse:273, resizewindow"
      ];

      # Media and brightness keys; repeat while held, work on the lock screen.
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # KeePassXC's unlock / access dialogs float, as on the Mac.
      windowrule = [ "match:class ^(org.keepassxc.KeePassXC)$, float on" ];
    };
  };

  programs = {
    fuzzel = {
      enable = true;
      # Launched apps run as their own systemd units under UWSM.
      settings.main.launch-prefix = "uwsm app --";
    };

    hyprlock = {
      enable = true;
      settings = {
        general.hide_cursor = true;
        # Fingerprint unlock alongside the password (needs `fprintd-enroll`).
        auth."fingerprint:enabled" = true;
        background = [
          {
            color = "rgb(1e1e2e)";
          }
        ];
        input-field = [
          {
            size = "300, 50";
            placeholder_text = "Password or fingerprint";
          }
        ];
      };
    };

    waybar = {
      enable = true;
      systemd.enable = true;
      settings.main = {
        layer = "top";
        position = "top";
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "battery"
          "tray"
        ];
        clock.format = "{:%a %b %d  %H:%M}";
        battery.format = "{capacity}%";
        network = {
          format-wifi = "{essid}";
          format-disconnected = "offline";
        };
        pulseaudio.format = "vol {volume}%";
      };
    };
  };

  services = {
    mako.enable = true;
    cliphist.enable = true;
    hyprpolkitagent.enable = true;

    hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = lock;
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
        listener = [
          {
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 330;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 1800;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };
  };
}
