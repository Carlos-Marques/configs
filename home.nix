{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.

  # Packages that should be installed to the user profile.
  home.packages = [ ];

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

    htop = {
      enable = true;
    };

    gh = {
      enable = true;
    };

    k9s = {
      enable = true;
    };

    vim = {
      enable = true;
      defaultEditor = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    starship = {
      enable = true;
      settings = {
        aws.disabled = true;
        nodejs.disabled = true;
        rust.disabled = true;
        nix_shell.disabled = true;

        git_branch.ignore_branches = ["development"];

        env_var.ACTIVE_AWS_PROFILE.format = "aws:[$env_value](red) ";
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
      enableAutosuggestions = true;
      enableCompletion = true;
    };
  };
}