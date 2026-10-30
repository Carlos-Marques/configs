# Home Manager config for the Mac only; shared settings are in default.nix.
{ lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Used by monorepo bin/devbox to tunnel clipboard images to Claude Code on
    # the box (Ctrl+V over ssh + tmux).
    pngpaste
    socat
    # Touch ID-gated KeePassXC reads for scripts and agents; pinned, see file.
    (callPackage ./pkgs/keepassxc-cli.nix { })
  ];

  # SSH keys live in the KeePassXC vault (its SSH Agent integration), not as
  # files in ~/.ssh. While the vault is unlocked KeePassXC loads them into this
  # agent with the confirm constraint, and the agent asks for Touch ID before
  # every use, like 1Password's agent. ~/.ssh/config's IdentityAgent and
  # KeePassXC's SSHAgent/AuthSockOverride point at its socket,
  # $(getconf DARWIN_USER_TEMP_DIR)/ssh-agent.
  services.ssh-agent.enable = true;
  launchd.agents.ssh-agent.config.EnvironmentVariables = {
    SSH_ASKPASS = lib.getExe (pkgs.callPackage ./pkgs/ssh-askpass-touchid.nix { });
    SSH_ASKPASS_REQUIRE = "force";
  };

  # The syncthing launchd agent logs here but doesn't create the directory.
  home.file."Library/Logs/Syncthing/.keep".text = "";

  # The Framework, reached only at its NetBird address (fixed per peer), never
  # via discovery or relays. Not in default.nix's shared device list: there it
  # would make the Framework list itself.
  services.syncthing.settings = {
    devices.framework-machine-broke = {
      id = "QSODOYS-56YZAZK-PYUB2BH-EBSDTOB-5XMGGZ2-LUGXJJB-UOW23VN-FVLDMQS";
      addresses = [ "tcp://100.111.220.154:22000" ];
    };
    folders."~/vault".devices = [ "framework-machine-broke" ];
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
