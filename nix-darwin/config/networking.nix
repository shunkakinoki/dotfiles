{
  networking = {
    knownNetworkServices = [
      "Wi-Fi"
      "Ethernet Adaptor"
      "Thunderbolt Ethernet"
    ];
  };

  # Split DNS: route only Tailscale domains through Tailscale's DNS proxy.
  # Regular DNS (internet, local router) is unaffected, so WiFi stays
  # connectable even when the Tailscale tunnel is unreachable.
  # Requires Tailscale's DNS proxy (100.100.100.100) to be active —
  # ensure accept-dns=true in the Tailscale app (default).
  environment.etc = {
    "resolver/ts.net".text = ''
      nameserver 100.100.100.100
    '';
  };
}
