# Encrypted DNS. Every lookup goes to Cloudflare over DNS-over-HTTPS through
# dnscrypt-proxy, with no plaintext fallback: when Cloudflare can't be reached,
# lookups fail instead of going out unencrypted. systemd-resolved sends
# *.netbird.cloud to NetBird's resolver (NetBird registers it on wt0) and
# everything else to dnscrypt-proxy. That holds as long as the NetBird
# dashboard has no nameserver group that takes all domains: NetBird would then
# make wt0 the default route. The DNS server a network hands out over DHCP is
# never used, except to get through a captive portal, and only after clicking
# a notification and touching the fingerprint reader (dns-portal below).
#
# Why DoH and not resolved's built-in DNS-over-TLS: same encryption, but DoT's
# port 853 is easy to single out and is often blocked on guest networks, where
# strict DoT would leave no DNS at all; DoH rides on 443 with ordinary HTTPS.
{
  lib,
  pkgs,
  ...
}:

let
  dnscryptListen = "127.0.0.1:5300";

  # Asks dnscrypt-proxy for a new random name each time, so no cache can answer:
  # any real reply, even "no such name", came from Cloudflare.
  encryptedOk = ''
    encrypted_ok() {
      status=$(dig +time=3 +tries=1 -p 5300 @127.0.0.1 "probe-$RANDOM$RANDOM.cloudflare.com" A |
        sed -n 's/.*status: \([A-Z]*\).*/\1/p' || true)
      [ "$status" = NXDOMAIN ] || [ "$status" = NOERROR ]
    }
  '';
  wifiDevices = ''nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "wifi" { print $1 }' '';

  # Root side of the captive-portal flow: the only thing that ever puts DNS
  # servers on a Wi-Fi link is a dns-portal click (NetworkManager doesn't, see
  # below), so whenever encrypted DNS answers, any Wi-Fi link with servers is
  # reverted. Also at start, so a restart or reboot never leaves one behind.
  dnsPortalRevert = pkgs.writeShellApplication {
    name = "dns-portal-revert";
    runtimeInputs = with pkgs; [
      coreutils
      dig
      gawk
      gnugrep
      gnused
      networkmanager
      systemd
    ];
    text = ''
      ${encryptedOk}
      revert_with_servers() {
        for d in $(${wifiDevices} || true); do
          if resolvectl dns "$d" | grep -qE '\): .+'; then
            resolvectl revert "$d" && echo "reverted $d"
          fi
        done
      }
      revert_with_servers
      while sleep 10; do
        if encrypted_ok; then
          revert_with_servers
        fi
      done
    '';
  };

  # User side: watches for encrypted DNS failing on Wi-Fi. A captive portal
  # blocks it until its terms are accepted, but keeps the network's own DNS
  # answering, so this asks that DNS directly for a known plain-HTTP page and
  # checks for a redirect. Then it only notifies. Clicking puts the network's
  # DNS server on that one link (resolved asks for admin authentication:
  # fingerprint) and opens the page; dns-portal-revert takes it off again.
  # Nothing switches to plaintext on its own, so a network can't trigger it
  # silently by faking a portal.
  dnsPortal = pkgs.writeShellApplication {
    name = "dns-portal";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      dig
      gawk
      gnugrep
      gnused
      libnotify
      networkmanager
      systemd
      xdg-utils
    ];
    text = ''
      ${encryptedOk}
      # What the probe fetches and the browser opens: portals intercept it
      # (neverssl.com, the usual choice, timed out on one guest network).
      check=http://nmcheck.gnome.org/check_network_status.txt
      # The connection the network's DNS was applied to (its D-Bus path, new on
      # every activation), and when the notification was last shown.
      applied=""
      asked=""
      connection() { nmcli -g GENERAL.CON-PATH device show "$1" 2>/dev/null || true; }
      first_dns() {
        nmcli -g IP4.DNS device show "$1" 2>/dev/null | awk -F' [|] ' '{ print $1; exit }' || true
      }
      while sleep 15; do
        dev=$(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null |
          awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }' || true)
        if [ -z "$dev" ]; then
          applied=""
          asked=""
          continue
        fi
        con=$(connection "$dev")
        if [ "$con" != "$applied" ]; then
          applied=""
        fi
        if encrypted_ok; then
          if [ -n "$applied" ]; then
            notify-send "DNS" "Encrypted DNS is back; the network's DNS is no longer used."
            applied=""
          fi
          asked=""
          continue
        fi
        # Ask once; if dismissed while DNS is still down, ask again after 2 minutes.
        [ -z "$applied" ] || continue
        [ -z "$asked" ] || [ $(($(date +%s) - asked)) -ge 120 ] || continue
        ns=$(first_dns "$dev")
        if ! [[ $ns =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
          echo "encrypted DNS down on $dev, no usable network DNS ('$ns')"
          continue
        fi
        ip=$(dig +short +time=3 +tries=1 "@$ns" nmcheck.gnome.org A | grep -E '^[0-9.]+$' | head -n1 || true)
        if [ -z "$ip" ]; then
          echo "encrypted DNS down on $dev, network DNS $ns doesn't answer either"
          continue
        fi
        code=$(curl -s -m 6 -o /dev/null -w '%{http_code}' --resolve "nmcheck.gnome.org:80:$ip" "$check" || true)
        if [ "$code" = 200 ]; then
          why="This network blocks encrypted DNS."
        else
          why="This network has a login page."
        fi
        echo "encrypted DNS down on $dev; probe via $ns -> $ip -> HTTP $code; asking"
        asked=$(date +%s)
        choice=$(notify-send -u critical -t 0 -A default="Use network DNS and open the login page" \
          "Encrypted DNS unavailable" \
          "$why Its own DNS isn't encrypted: click only if you trust this network for now." || true)
        echo "notification answer: ''${choice:-dismissed}"
        [ "$choice" = default ] || continue
        # The click can come much later: apply only to the same connection, and
        # only if encrypted DNS still fails.
        if [ "$(connection "$dev")" != "$con" ] || [ "$(first_dns "$dev")" != "$ns" ]; then
          echo "the network changed before the click; not applied"
          continue
        fi
        if encrypted_ok; then
          echo "encrypted DNS answers again; not applied"
          continue
        fi
        # A link with servers and no domains is a default route, so lookups also
        # go to it.
        if resolvectl dns "$dev" "$ns"; then
          applied=$con
          echo "network DNS $ns now serves $dev; opening $check"
          xdg-open "$check" >/dev/null 2>&1 || true
        else
          echo "network DNS not applied (authentication refused?)"
        fi
      done
    '';
  };
in
{
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      listen_addresses = [ dnscryptListen ];
      server_names = [
        "cloudflare"
        "cloudflare-ipv6"
      ];
      # Cloudflare's DoH endpoints, from the signed resolver list
      # (DNSCrypt/dnscrypt-resolvers v3/public-resolvers.md, minisign key
      # RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3, verified
      # 2026-11-05). Pinned instead of downloading the list, which goes
      # through plaintext bootstrap resolvers; the stamps carry the addresses,
      # so the bootstrap resolvers are never used. Certificates are checked
      # against the system CAs: 1.0.0.1 as dns.cloudflare.com, the IPv6 one by
      # address. Both stamps advertise DNSSEC validation, no logs, no filtering.
      sources = { };
      static = {
        cloudflare.stamp = "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5";
        cloudflare-ipv6.stamp = "sdns://AgcAAAAAAAAAFlsyNjA2OjQ3MDA6NDcwMDo6MTExMV0AGlsyNjA2OjQ3MDA6NDcwMDo6MTExMV06NDQzCi9kbnMtcXVlcnk";
      };
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      # The only servers resolved has, apart from NetBird's on wt0. No `~.`
      # here: it would make these win over a link's servers, and the network
      # DNS a dns-portal click puts on the Wi-Fi link would never be asked.
      DNS = [ dnscryptListen ];
      # Empty: no built-in fallback servers, which would be plaintext.
      FallbackDNS = "";
      # Cloudflare validates DNSSEC; resolved's own validation is known to
      # break on networks that mangle DNS.
      DNSSEC = false;
      DNSOverTLS = false;
      # No name broadcasting on shared networks.
      LLMNR = false;
      MulticastDNS = false;
    };
  };

  # NetworkManager doesn't hand DHCP DNS servers to resolved: they'd become a
  # second default route, and lookups would also go to them in plaintext.
  # dns=none alone isn't enough: systemd-resolved=true (its default) still sends
  # each connection's servers to resolved.
  networking.networkmanager.dns = lib.mkForce "none";
  networking.networkmanager.settings.main.systemd-resolved = false;

  # A network's DNS applied for a portal never carries over to the next
  # network: dropped whenever a Wi-Fi link comes up or goes down.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "dns-portal-revert-on-change" ''
        case "$1:$2" in
          wl*:up | wl*:down | wl*:pre-down) ${pkgs.systemd}/bin/resolvectl revert "$1" || true ;;
        esac
      '';
    }
  ];

  systemd.services.dns-portal-revert = {
    description = "Take a captive portal's DNS off Wi-Fi once encrypted DNS works";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-resolved.service"
      "dnscrypt-proxy.service"
    ];
    serviceConfig = {
      ExecStart = "${dnsPortalRevert}/bin/dns-portal-revert";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.user.services.dns-portal = {
    description = "Offer the network's DNS for a captive portal when encrypted DNS fails";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${dnsPortal}/bin/dns-portal";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
