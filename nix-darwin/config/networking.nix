{
  lib,
  pkgs,
  tailscaleSetFlags,
  ...
}:
{
  networking = {
    applicationFirewall = {
      allowSigned = true;
      allowSignedApp = true;
      blockAllIncoming = false;
      enable = false;
      enableStealthMode = false;
    };
    knownNetworkServices = [
      "Wi-Fi"
      "Ethernet Adaptor"
      "Thunderbolt Ethernet"
    ];
  };

  # Tailscale is installed as a Homebrew app on macOS, so keep its mutable
  # DNS preference aligned with this declarative split-DNS configuration.
  system.activationScripts.tailscaleDns.text = ''
    if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
      ${pkgs.tailscale}/bin/tailscale set ${lib.escapeShellArgs tailscaleSetFlags}
    fi
  '';
}
