# Home Manager config shared by every machine; platform bits are in darwin.nix
# and linux.nix next to this file.
{ config, pkgs, ... }:

let
  # Syncthing peers; keys in services.syncthing.settings.devices below.
  peers = [
    "phone-machine-broke"
    "m2-machine-broke"
    "arch-machine-broke"
    "arch-machine-broke-mini"
  ];
in
{
  # Per-user nix.conf. The private cachix cache needs the netrc below, and as a
  # trusted user these settings are forwarded to the daemon, so they live here
  # rather than in the system config.
  nix = {
    enable = true;

    settings = {
      extra-substituters = [
        "https://monorepo.cachix.org"
        "https://nix-community.cachix.org"
      ];

      extra-trusted-public-keys = [
        "monorepo.cachix.org-1:xI4avJXNAOTcGcUdqG1FXRwpo5JrHCnoTsA2qzunTKI="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      netrc-file = "${config.home.homeDirectory}/.config/nix/netrc";
    };
  };

  home.packages = with pkgs; [
    awscli2
    cachix
    comma
    discord
    jq
    kubectl
    magic-wormhole
    nil
    nixfmt
    wget
  ];

  services = {
    # Declaring `settings` makes this config the source of truth: folders and
    # devices added in the web UI are removed on the next switch (overrideFolders
    # / overrideDevices). Device IDs are public key fingerprints, not secrets.
    # This Mac's own ID is implicit and must not be listed.
    syncthing = {
      enable = true;
      settings = {
        devices = {
          "phone-machine-broke" = {
            id = "3PTU2DO-5N424O3-J4AJLNO-5UOEJLN-AZOFJQ5-IRHBQTK-BF7TBWE-2C7F7QT";
            introducer = true;
          };
          "m2-machine-broke".id = "DXSIAHN-N73HMPT-TD6JKTG-HU2D2T6-EXWJO5Z-SGDAYVM-VIF2KSL-JBFCXQJ";
          "arch-machine-broke".id = "7ZE5FCA-OUHOBTF-MLNLMS5-66WDUFU-WRXUQFC-SNL3KX5-KL3DDJ6-HJND7AZ";
          "arch-machine-broke-mini".id = "GM6HWH3-GJA62NC-MKYQDWO-37R5O52-FTLJJWO-36B4KBL-QKBHC5F-BW7VYQ6";
        };

        folders = {
          "~/org" = {
            id = "org";
            label = "org";
            devices = peers;
          };

          # KeePassXC database (see README.md). Every client rewrites the whole
          # .kdbx on save, so concurrent edits on two offline devices produce a
          # `.sync-conflict-*` file; versioning keeps a year of history so a bad
          # merge is never lossy.
          "~/vault" = {
            id = "vault";
            label = "vault";
            devices = peers;
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "31536000";
              };
            };
          };
        };
      };
    };
  };

  programs = {
    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };

    htop = {
      enable = true;
    };

    gh = {
      enable = true;
    };

    k9s = {
      enable = true;
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      withRuby = true;
      withPython3 = true;
      initLua = ''
        vim.g.mapleader = " "

        vim.opt.conceallevel = 2
        vim.opt.concealcursor = 'nc'

        vim.opt.wrap = false

        local org = require('orgmode')
        org.setup({
          org_agenda_files = {'~/org/*.org'},
          org_default_notes_file = '~/org/refile.org',
        })


        local wk = require("which-key")
        wk.setup({})
      '';
      plugins = with pkgs.vimPlugins; [
        orgmode
        which-key-nvim
      ];
    };

    ghostty = {
      enable = true;
      # https://ghostty.org/docs/config/reference
      settings = {
        # Ghostty sets TERM=xterm-ghostty, which stock remote hosts (e.g. Ubuntu
        # 24.04's ncurses) don't know, so tmux over ssh aborts. These make the
        # shell-integration `ssh` wrapper install Ghostty's terminfo on the host
        # on first connect and fall back to xterm-256color where it can't.
        shell-integration-features = "ssh-terminfo,ssh-env";
        # No "close this window?" prompts; tmux owns the sessions.
        confirm-close-surface = false;
        quit-after-last-window-closed = true;
        mouse-hide-while-typing = true;
      };
    };

    direnv = {
      enable = true;
      config = {
        hide_env_diff = true;
      };

      nix-direnv = {
        enable = true;
      };

      # Written to ~/.config/direnv/direnvrc, which direnv sources *after*
      # lib/*.sh (nix-direnv), so these replace nix-direnv 3.2.0's versions.
      #
      # nix-direnv invalidates a `use flake` cache when any file in
      # DIRENV_WATCHES is newer than that cache's .rc. With nested `use flake`
      # (monorepo: every project .envrc is `source_up` + `use flake`) each
      # cache's .rc is in the other's watch list, and _nix_refresh_gcroots
      # touches the .rc on every cache *hit* (its `flake-profile-*` glob also
      # matches the .rc), so root and project caches invalidate each other on
      # every load: one `cd` = two full re-evals (tree copy + eval + `nix
      # flake archive`, ~30-60s each). Compare only against real inputs, and
      # only touch the gcroot symlinks. Drop once fixed upstream.
      stdlib = ''
        _nix_direnv_watches() {
          local -n _watches=$1
          if [[ -z ''${DIRENV_WATCHES-} ]]; then
            return
          fi
          local line path regex='"[Pp]ath": "(.+)"$'
          while IFS= read -r line; do
            if [[ $line =~ $regex ]]; then
              # shellcheck disable=2059
              path=$(printf "''${BASH_REMATCH[1]}")
              case $path in
                "''${XDG_DATA_HOME:-''${HOME:-/var/empty}/.local/share}/direnv/allow/"*) continue ;;
                */flake-profile-*.rc | */nix-profile-*.rc) continue ;;
              esac
              _watches+=("$path")
            fi
          done < <($direnv show_dump "''${DIRENV_WATCHES}")
        }

        _nix_refresh_gcroots() {
          local layout_dir f links=()
          layout_dir=$(direnv_layout_dir)
          for f in "$layout_dir"/flake-profile-* "$layout_dir"/flake-inputs/* "$layout_dir"/nix-profile-*; do
            [[ -L $f ]] && links+=("$f")
          done
          if (( ''${#links[@]} )) && ! touch -h "''${links[@]}" 2>/dev/null; then
            _nix_direnv_warning "could not refresh gcroots; layout directory may be read-only"
          fi
        }
      '';
    };

    starship = {
      enable = true;
      settings = {
        aws.disabled = true;
        gcloud.disabled = true;
        nodejs.disabled = true;
        rust.disabled = true;
        nix_shell.disabled = true;
        kubernetes = {
          disabled = false;
          detect_extensions = [
            "yaml"
            "yml"
            "tf"
          ];
        };
      };
    };

    atuin = {
      enable = true;
      settings = {
        search_mode = "fuzzy";
        filter_mode = "directory";
        filter_mode_shell_up_key_binding = "directory";
      };
    };

    zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      defaultKeymap = "viins";
      history = {
        size = 10000000;
        save = 10000000;
        extended = true;
        ignoreDups = true;
        ignoreSpace = true;
        share = true;
      };
    };

    git = {
      enable = true;
      lfs = {
        enable = true;
      };
      settings = {
        user = {
          name = "Carlos Marques";
          email = "carlosmarques.personal@gmail.com";
        };
        push = {
          autoSetupRemote = true;
        };
        commit = {
          verbose = true;
        };
      };
    };

    # The nixpkgs wrapper already bundles the preview deps (ffmpeg, poppler,
    # imagemagick, resvg, fd, rg, fzf, zoxide, 7zz), so previews work out of the
    # box. Images render natively in Ghostty via the kitty graphics protocol.
    yazi = {
      enable = true;
      # Installs the `y` wrapper: like `yazi`, but cd's to the last dir on exit.
      enableZshIntegration = true;
      shellWrapperName = "y";
      settings = {
        mgr = {
          show_hidden = true;
          sort_by = "natural";
          sort_dir_first = true;
        };
      };
    };
  };
}
