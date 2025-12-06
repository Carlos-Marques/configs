{ config, pkgs, ... }:

{
  nix = {
    enable = true;

    settings = {
      # what cachix use wrote to nix.conf
      extra-substituters = [
        "https://monorepo.cachix.org"
      ];

      extra-trusted-public-keys = [
        "monorepo.cachix.org-1:xI4avJXNAOTcGcUdqG1FXRwpo5JrHCnoTsA2qzunTKI="
      ];

      # point Nix at your per-user netrc
      netrc-file = "${config.home.homeDirectory}/.config/nix/netrc";
    };
  };

  # Home Manager needs a bit of information about you and the
  # paths it should manage.

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    discord
    obsidian
    jq
    nil
    nixpkgs-fmt
    magic-wormhole
    awscli2
    wget
    kubectl
    comma
    cachix
    (writeShellScriptBin "new-project" (builtins.readFile ./scripts/new-project/new-project.sh))
  ];

  home.file = {
    ".local/share/new-project/flake.nix".source = ./scripts/new-project/flake.nix;
    ".local/share/new-project/.envrc".source = ./scripts/new-project/.envrc;
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  services = {
    syncthing = {
      enable = true;
    };
  };

  programs = {
    # Let Home Manager install and manage itself.
    home-manager = {
      enable = true;
    };

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
      extraLuaConfig = ''
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

    direnv = {
      enable = true;
      config = {
        hide_env_diff = true;
      };

      nix-direnv = {
        enable = true;
      };
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
          detect_extensions = [ "yaml" "yml" "tf" ];
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
    };

    git = {
      enable = true;
      userName = "Carlos Marques";
      userEmail = "carlosmarques.personal@gmail.com";
      lfs = {
        enable = true;
      };
      extraConfig = {
        push = {
          autoSetupRemote = true;
        };
        commit = {
          verbose = true;
        };
      };
    };

    nnn = {
      enable = true;
    };
  };
}
