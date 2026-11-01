# Renews this device's NetBird SSO session before it expires (NetBird Cloud
# logs SSO peers out after 24 h), from the login the browser already holds.
# NetBird Cloud's login page doesn't force a fresh login (no prompt=login), so
# while the browser is signed in the tab NetBird opens finishes by itself in
# a few seconds. Once that login is gone (signed out, or revoked at Google)
# the tab waits for a real sign-in, and an unattended device drops off the
# mesh at its expiry, as it would without this.
#
# Run hourly. It renews when under 6 h are left, logs back in after an expiry,
# and leaves NetBird alone after `netbird down`.
{
  writeShellApplication,
  jq,
  # The CLI matching the running daemon.
  netbird,
}:

writeShellApplication {
  name = "netbird-renew";
  runtimeInputs = [ jq ];
  text = ''
    # No status (daemon not running): nothing to do.
    action=$(${netbird} status --json 2>/dev/null | jq -r '
      if .daemonStatus == "NeedsLogin" or .daemonStatus == "LoginFailed"
         or .daemonStatus == "SessionExpired" then "up"
      elif .daemonStatus == "Connected" and .sessionExpiresAt != null
         and (.sessionExpiresAt | sub("\\.[0-9]+"; "") | fromdateiso8601) - now < 6 * 3600
        then "extend"
      else "none" end') || exit 0

    case $action in
      up) exec ${netbird} up ;;
      extend) exec ${netbird} login --extend ;;
    esac
  '';
}
