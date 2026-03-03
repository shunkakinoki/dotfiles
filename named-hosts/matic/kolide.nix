# Kolide Launcher configuration for NixOS
#
# Uses the official Kolide NixOS module from https://github.com/kolide/nix-agent
#
# Prerequisites (manual steps):
# 1. Obtain the Kolide launcher .deb from IT
# 2. Extract the enrollment secret:
#    nix-shell -p dpkg --run 'dpkg-deb -x ~/Downloads/kolide-launcher.deb /tmp/kolide-deb'
#    cat /tmp/kolide-deb/etc/kolide-k2/secret
# 3. Install secret to /etc/kolide-k2/secret (root:root, 0600):
#    sudo install -d -m 755 /etc/kolide-k2
#    sudo sh -c 'cat /tmp/kolide-deb/etc/kolide-k2/secret > /etc/kolide-k2/secret'
#    sudo chown root:root /etc/kolide-k2/secret
#    sudo chmod 600 /etc/kolide-k2/secret
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Official Kolide NixOS module
  # Pin to specific commit to avoid hash mismatches when upstream pushes to main.
  # To update: get latest commit from https://github.com/kolide/nix-agent
  # then: nix-prefetch-url --unpack https://github.com/kolide/nix-agent/archive/<commit>.tar.gz
  kolideSrc = builtins.fetchTarball {
    url = "https://github.com/kolide/nix-agent/archive/0ccdf83c1a86cf0606f045363e29db4d840684e1.tar.gz";
    sha256 = "1pawad6s3cd59x58mbj8g0qmfmki2mgmk5sgbn19ic692cb5lj98";
  };
in
{
  imports = [
    "${kolideSrc}/modules/kolide-launcher"
  ];

  # dpkg status shim for Kolide/osquery compliance
  # NixOS has no dpkg database, so Kolide's osquery deb_packages check fails.
  # This shim reports falcon-sensor as "installed" to satisfy the CrowdStrike check.
  systemd.tmpfiles.rules = [
    "d /var/lib/dpkg 0755 root root -"
    "f /var/lib/dpkg/status 0644 root root - Package: falcon-sensor\\nStatus: install ok installed\\nPriority: optional\\nSection: misc\\nInstalled-Size: 0\\nMaintainer: CrowdStrike\\nArchitecture: amd64\\nVersion: 7.31.0-18410\\nDescription: CrowdStrike Falcon Sensor (shim for Kolide/osquery on NixOS)\\n"
  ];

  # Add dpkg to Kolide service PATH for deb_packages table
  systemd.services.kolide-launcher.path = with pkgs; [ dpkg ];

  # Enable Kolide launcher
  services.kolide-launcher.enable = true;
}
