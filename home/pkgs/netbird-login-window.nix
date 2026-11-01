# NetBird's SSO logins (`netbird up`, `netbird login --extend`, `netbird ssh`)
# in a Brave window of their own that opens hidden and closes when done,
# instead of a tab in the current Brave window that takes focus. NetBird opens
# logins with $BROWSER when it's set; the `netbird` wrapper below sets it.
#
# The window is an app window (`brave --app`): same profile, so the existing
# sign-in completes the login, with its own class, which home/linux.nix's
# Hyprland rule sends to a hidden special workspace without focus. If the
# login hasn't finished after 15 s it needs you (signed out, account choice),
# and the window moves to the current workspace and takes focus. It closes on
# NetBird's "NetBird Login" page, shown once the browser hands back the login.
{
  writeShellApplication,
  writeShellScriptBin,
  jq,
  # The real CLI, matching the running daemon.
  netbird,
}:

let
  # Brave names app windows after the URL's host and path.
  classPrefix = "brave-login.netbird.io__";

  window = writeShellApplication {
    name = "netbird-login-window";
    runtimeInputs = [ jq ];
    text = ''
      url=$1
      logins() {
        hyprctl clients -j | jq -c '[.[] | select(.class | startswith("${classPrefix}")) | .address]'
      }
      dispatch() { hyprctl dispatch "$1" >/dev/null; }

      before=$(logins)
      # Its own scope, so a Brave that wasn't running yet outlives this unit.
      uwsm app -- brave --app="$url"
      win=
      for _ in $(seq 1 40); do
        win=$(logins | jq -r --argjson old "$before" '. - $old | .[0] // empty')
        [ -n "$win" ] && break
        sleep 0.25
      done
      [ -n "$win" ] || exit 1

      # 600 * 0.5 s: NetBird's own 5 min limit on a login.
      for i in $(seq 1 600); do
        title=$(hyprctl clients -j | jq -r --arg a "$win" '.[] | select(.address == $a) | .title')
        # Closed by hand.
        [ -n "$title" ] || exit 0
        if [ "$title" = "NetBird Login" ]; then
          dispatch "hl.dsp.window.close({ window = \"address:$win\" })"
          exit 0
        fi
        if [ "$i" -eq 30 ]; then
          ws=$(hyprctl activeworkspace -j | jq -r .id)
          dispatch "hl.dsp.window.move({ workspace = \"$ws\", window = \"address:$win\" })"
          sleep 0.2
          dispatch "hl.dsp.focus({ window = \"address:$win\" })"
        fi
        sleep 0.5
      done
    '';
  };

  browser = writeShellApplication {
    name = "netbird-browser";
    text = ''
      case $1 in
        https://login.netbird.io/*) ;;
        *) exec xdg-open "$1" ;;
      esac
      # Detached into its own unit: NetBird, or the renewal's unit, can exit
      # as soon as the login completes, which would take this along before
      # it closes the window.
      exec systemd-run --user --quiet --collect -- ${window}/bin/netbird-login-window "$1"
    '';
  };
in
writeShellScriptBin "netbird" ''
  BROWSER=${browser}/bin/netbird-browser exec ${netbird} "$@"
''
