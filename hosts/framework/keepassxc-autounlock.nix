# KeePassXC opens unlocked, hidden in the tray, right after logging in at
# greetd (fingerprint or password), without typing the master password and
# without it passing through anything other programs running as the user can
# read:
#
# - The master password is sealed with systemd-creds to this machine's TPM
#   (PCR 7: Secure Boot with our keys) plus the host key, root-only. Seal it,
#   or reseal after changing it or after a BIOS update changes PCR 7, with
#   `sudo keepassxc-autounlock-seal` (it asks for the password).
# - A session step in greetd's PAM stack (root, only after a successful
#   login) starts keepassxc-autounlock.service. Nothing else starts it: users
#   can't start system units.
# - The service unseals the password and starts KeePassXC as a unit in the
#   user's systemd manager, writing the password into that one process's stdin
#   (--pw-stdin) over a private pipe. KeePassXC makes itself non-dumpable and
#   ptrace_scope is 1, so other programs running as the user can't read it
#   there either.
# - If unsealing fails, KeePassXC starts locked and asks for the password.
#
# Later unlocks take the fingerprint (Quick Unlock, keepassxc.nix).
{
  config,
  pkgs,
  user,
  ...
}:

let
  credFile = "/var/lib/keepassxc-autounlock/vault.cred";
  home = config.users.users.${user}.home;
  systemd = config.systemd.package;

  seal = pkgs.writeShellApplication {
    name = "keepassxc-autounlock-seal";
    runtimeInputs = [
      systemd
      pkgs.coreutils
    ];
    # Asks for the password itself (hidden) rather than reading a pipe, so it
    # never ends up in shell history, and only seals one that opens the vault.
    text = ''
      if [ ! -t 0 ]; then
        echo "Run it in a terminal: sudo keepassxc-autounlock-seal" >&2
        exit 1
      fi
      read -rsp "KeePassXC master password: " pw
      echo
      if ! printf '%s\n' "$pw" | /run/current-system/sw/bin/keepassxc-cli ls -q \
          -k ${home}/.config/keepassxc/vault.keyx ${home}/vault/vault.kdbx >/dev/null 2>&1; then
        echo "That password doesn't open the vault; nothing sealed." >&2
        exit 1
      fi
      install -d -m 700 /var/lib/keepassxc-autounlock
      printf '%s' "$pw" | systemd-creds encrypt --name=keepassxc-vault --with-key=tpm2+host --tpm2-pcrs=7 - ${credFile}
      chmod 600 ${credFile}
      echo "Sealed."
    '';
  };
in
{
  environment.systemPackages = [ seal ];

  security.pam.services.greetd.rules.session.keepassxc-autounlock = {
    order = 20000;
    control = "optional";
    modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
    args = [
      "quiet"
      (toString (
        pkgs.writeShellScript "keepassxc-autounlock-pam" ''
          [ "$PAM_TYPE" = open_session ] && [ "$PAM_USER" = ${user} ] || exit 0
          ${systemd}/bin/systemctl start --no-block keepassxc-autounlock.service
          exit 0
        ''
      ))
    ];
  };

  systemd.services.keepassxc-autounlock = {
    description = "Open KeePassXC unlocked in ${user}'s session after a login";
    path = [
      systemd
      pkgs.coreutils
      pkgs.gnugrep
    ];
    # 255: systemd-run --pipe when KeePassXC is killed at logout.
    serviceConfig.SuccessExitStatus = "255";
    script = ''
      um() { systemctl --machine=${user}@.host --user "$@"; }
      # ExecStopPost empties the SSH agent whenever KeePassXC stops: killed at
      # logout or crashing, it can't remove its keys itself.
      sock=/run/user/$(id -u ${user})/ssh-agent
      run() {
        systemd-run --machine=${user}@.host --user --unit=keepassxc --collect --quiet \
          --setenv=SSH_AUTH_SOCK="$sock" --property=ExecStopPost="${pkgs.openssh}/bin/ssh-add -D" "$@"
      }

      # Wait for the graphical session and its tray (Waybar), so KeePassXC can
      # start hidden there.
      for _ in $(seq 1 120); do
        um show-environment 2>/dev/null | grep -q '^WAYLAND_DISPLAY=' && um is-active --quiet waybar.service && break
        sleep 1
      done
      um is-active --quiet keepassxc.service && exit 0

      kpxc=(/run/current-system/sw/bin/keepassxc)
      if systemd-creds decrypt --name=keepassxc-vault ${credFile} - >/dev/null 2>&1; then
        # Straight from systemd-creds into KeePassXC's stdin; never in a
        # variable or file. --pipe keeps this service up while KeePassXC runs.
        systemd-creds decrypt --name=keepassxc-vault ${credFile} - |
          run --pipe -- "''${kpxc[@]}" --pw-stdin \
            --keyfile ${home}/.config/keepassxc/vault.keyx ${home}/vault/vault.kdbx
      else
        echo "No sealed master password (or it no longer unseals); starting KeePassXC locked."
        run -- "''${kpxc[@]}" ${home}/vault/vault.kdbx
      fi
    '';
  };
}
