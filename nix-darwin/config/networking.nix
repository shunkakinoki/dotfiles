{ pkgs, ... }:
{
  networking = {
    applicationFirewall = {
      allowSigned = true;
      allowSignedApp = true;
      blockAllIncoming = false;
      enable = false;
      enableStealthMode = false;
    };
    dns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    knownNetworkServices = [
      "Wi-Fi"
      "Ethernet Adaptor"
      "Thunderbolt Ethernet"
    ];
  };

  # Split DNS: route only Tailscale domains through Tailscale's DNS proxy.
  # Keep Tailscale from installing its transient DNS proxy as the global
  # resolver; regular internet DNS stays on the Wi-Fi service below.
  environment.etc = {
    "resolver/ts.net".text = ''
      nameserver 100.100.100.100
    '';
  };

  # Tailscale is installed as a Homebrew app on macOS, so keep its mutable
  # DNS preference aligned with this declarative split-DNS configuration.
  system.activationScripts.tailscaleDns.text = ''
    if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
      ${pkgs.tailscale}/bin/tailscale set --accept-dns=false || true
    fi
  '';
}
