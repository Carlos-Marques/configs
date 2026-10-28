# Home Manager config for the Mac only; shared settings are in default.nix.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Used by monorepo bin/devbox to tunnel clipboard images to Claude Code on
    # the box (Ctrl+V over ssh + tmux).
    pngpaste
    socat
    # Touch ID-gated KeePassXC reads for scripts and agents; pinned, see file.
    (callPackage ./pkgs/keepassxc-cli.nix { })
  ];

  # The syncthing launchd agent logs here but doesn't create the directory.
  home.file."Library/Logs/Syncthing/.keep".text = "";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  programs = {
    ghostty = {
      # Installed via environment.systemPackages in darwin.nix (see comment
      # there); this module only manages ~/.config/ghostty/config.
      package = null;
      settings = {
        # Send Option as Alt so tmux/neovim alt-bindings work.
        macos-option-as-alt = true;
        keybind = [
          # Rename the current window (View > Change Title… has no default key).
          "super+shift+t=prompt_surface_title"
          # `performable:` makes ⌘V fall through to the running program when the
          # clipboard has no text (e.g. a screenshot). Claude Code binds cmd+v to
          # image paste in ~/.claude/keybindings.json, so one key pastes both.
          "performable:super+v=paste_from_clipboard"
        ];
      };
    };

    zsh = {
      profileExtra = ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      '';
      # The config isn't named after the MDM hostname (see flake.nix), so
      # darwin-rebuild can't pick it automatically.
      shellAliases.rebuild = "sudo darwin-rebuild switch --flake ~/configs#m4-machine-broke";
    };
  };
}
