# Home Manager config for NixOS machines (Hyprland); shared settings are in
# default.nix.
{ lib, pkgs, ... }:

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

  # SSH keys live in the KeePassXC vault; see darwin.nix. Here the agent's
  # confirm-before-use check is a polkit authorization (action in
  # hosts/framework), which hyprpolkitagent answers with the fingerprint.
  # KeePassXC's SSHAgent/AuthSockOverride points at $XDG_RUNTIME_DIR/ssh-agent.
  services.ssh-agent.enable = true;
  systemd.user.services.ssh-agent.Service.Environment = [
    "SSH_ASKPASS=${pkgs.writeShellScript "ssh-askpass-polkit" ''
      # Exit 0 allows one use of the key. Only confirmations come here, never
      # passphrase prompts.
      [ "$SSH_ASKPASS_PROMPT" = confirm ] || exit 1
      ${pkgs.polkit}/bin/pkcheck --action-id local.ssh-agent.use-key \
        --process $$ --allow-user-interaction >/dev/null 2>&1
    ''}"
    "SSH_ASKPASS_REQUIRE=force"
  ];

  # Dark mode. Apps ask the desktop portal (org.freedesktop.appearance
  # color-scheme), which xdg-desktop-portal-gtk answers from dconf's
  # org.gnome.desktop.interface color-scheme; Hyprland's portal has no
  # Settings. Brave (and web pages' prefers-color-scheme), GTK 4, libadwaita,
  # Ghostty and KeePassXC follow it, live. gtk3.colorScheme sets that key
  # and GTK 3's settings.ini, since GTK 3 (file picker, Waybar's tray menus)
  # never reads the portal. Not GTK 4's settings.ini: libadwaita warns at
  # every start when that says prefer-dark.
  gtk = {
    enable = true;
    gtk3.colorScheme = "dark";
    # GTK 3's file picker draws its icons from Adwaita, which nothing else
    # installs here.
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };
  # Other Qt apps take GTK 3's dark colors (and font, and file dialog).
  # KeePassXC's default "Automatic" theme reads the portal itself.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  # Keeps the NetBird login from expiring; see the file. Only in the graphical
  # session, where the login can open the browser. OnCalendar timers also fire
  # on resume when an hour passed in sleep; OnActiveSec checks right at login.
  systemd.user.services.netbird-renew = {
    Unit.Description = "Renew the NetBird login from the browser's";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe (
        pkgs.callPackage ./pkgs/netbird-renew.nix { netbird = "/run/current-system/sw/bin/netbird"; }
      );
    };
  };
  systemd.user.timers.netbird-renew = {
    Unit.PartOf = [ "graphical-session.target" ];
    Timer = {
      OnActiveSec = "30s";
      OnCalendar = "hourly";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

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
    # systemd session, so home-manager only writes hyprland.lua.
    package = null;
    portalPackage = null;
    systemd.enable = false;
    # Lua config: Hyprland 0.56 warns at every start that the .conf format is
    # removed in 0.57. Each attribute below becomes an hl.<name>(...) call;
    # `_args` gives multi-argument calls (hl.bind(keys, dispatcher, opts)).
    # API: https://wiki.hypr.land and the example hyprland.lua upstream.
    configType = "lua";

    settings =
      let
        lua = lib.generators.mkLuaInline;
        str = lib.generators.toLua { };
        exec = cmd: lua "hl.dsp.exec_cmd(${str cmd})";
        focus = arg: lua "hl.dsp.focus(${str arg})";
        move = arg: lua "hl.dsp.window.move(${str arg})";
        bind = keys: dispatcher: {
          _args = [
            keys
            dispatcher
          ];
        };
        bindWith = opts: keys: dispatcher: {
          _args = [
            keys
            dispatcher
            opts
          ];
        };
        directions = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";
        };
        workspaces = [
          "1"
          "2"
          "3"
          "4"
          "Q"
          "W"
          "E"
          "R"
        ];
        # Numbered workspaces by number, lettered ones by name.
        workspace = ws: if builtins.match "[0-9]+" ws != null then lib.toInt ws else "name:${ws}";
      in
      {
        monitor = {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        };

        config = {
          input = {
            kb_layout = "us";
            # Mac-like trackpad: natural scrolling, tap to click.
            touchpad = {
              natural_scroll = true;
              tap_to_click = true;
            };
          };

          general = {
            gaps_in = 4;
            gaps_out = 8;
            layout = "dwindle";
          };

          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
          };
        };

        # Three-finger swipe between workspaces.
        gesture = {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        };

        # No exec-once for KeePassXC: hosts/framework/keepassxc-autounlock.nix
        # starts it, already unlocked, after each login.

        # Same keys as AeroSpace in darwin.nix (Alt as the modifier); Super
        # takes the Mac's Cmd shortcuts.
        bind =
          lib.mapAttrsToList (
            key: dir:
            bind "ALT + ${key}" (focus {
              direction = dir;
            })
          ) directions
          ++ lib.mapAttrsToList (
            key: dir:
            bind "ALT + SHIFT + ${key}" (move {
              direction = dir;
            })
          ) directions
          ++ [
            (bind "ALT + f" (lua "hl.dsp.window.fullscreen()"))
            # AeroSpace's accordion / tiles toggles: tab the window into a
            # group, or flip the split direction.
            (bind "ALT + s" (lua "hl.dsp.group.toggle()"))
            (bind "ALT + t" (lua ''hl.dsp.layout("togglesplit")''))
          ]
          ++ map (
            ws:
            bind "ALT + ${lib.toLower ws}" (focus {
              workspace = workspace ws;
            })
          ) workspaces
          ++ map (
            ws:
            bind "ALT + SHIFT + ${lib.toLower ws}" (move {
              workspace = workspace ws;
            })
          ) workspaces
          ++ [
            (bind "ALT + period" (focus {
              monitor = "+1";
            }))
            (bind "ALT + comma" (focus {
              monitor = "-1";
            }))

            (bind "SUPER + Return" (exec terminal))
            (bind "SUPER + space" (exec "fuzzel"))
            (bind "SUPER + q" (lua "hl.dsp.window.close()"))
            # ⌃⌘Q / ⇧⌘4 / ⇧⌘3 on the Mac.
            (bind "SUPER + CTRL + q" (exec "loginctl lock-session"))
            (bind "SUPER + SHIFT + 4" (exec ''grim -g "$(slurp)" - | wl-copy''))
            (bind "SUPER + SHIFT + 3" (exec "grim - | wl-copy"))
            (bind "SUPER + SHIFT + Escape" (exec "uwsm stop"))

            # Drag with Alt held: left button moves, right button resizes.
            (bindWith { mouse = true; } "ALT + mouse:272" (lua "hl.dsp.window.drag()"))
            (bindWith { mouse = true; } "ALT + mouse:273" (lua "hl.dsp.window.resize()"))
          ]
          # Media and brightness keys work on the lock screen; volume and
          # brightness repeat while held.
          ++
            map
              (
                b:
                bindWith {
                  locked = true;
                  repeating = true;
                } b.key (exec b.cmd)
              )
              [
                {
                  key = "XF86AudioRaiseVolume";
                  cmd = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
                }
                {
                  key = "XF86AudioLowerVolume";
                  cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
                }
                {
                  key = "XF86MonBrightnessUp";
                  cmd = "brightnessctl set 5%+";
                }
                {
                  key = "XF86MonBrightnessDown";
                  cmd = "brightnessctl set 5%-";
                }
              ]
          ++ map (b: bindWith { locked = true; } b.key (exec b.cmd)) [
            {
              key = "XF86AudioMute";
              cmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            }
            {
              key = "XF86AudioMicMute";
              cmd = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            }
            {
              key = "XF86AudioPlay";
              cmd = "playerctl play-pause";
            }
            {
              key = "XF86AudioNext";
              cmd = "playerctl next";
            }
            {
              key = "XF86AudioPrev";
              cmd = "playerctl previous";
            }
          ];

        # KeePassXC's unlock / access dialogs float, as on the Mac.
        window_rule = {
          name = "keepassxc-float";
          match.class = "^(org.keepassxc.KeePassXC)$";
          float = true;
        };
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
