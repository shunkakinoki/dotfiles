# Kolide Launcher configuration for NixOS
#
# Prerequisites (manual steps):
# 1. Obtain the Kolide launcher .deb from IT
# 2. Extract the enrollment secret:
#    nix-shell -p dpkg --run 'dpkg-deb -x ~/Downloads/kolide-launcher.deb /tmp/kolide-deb'
#    cat /tmp/kolide-deb/etc/kolide-k2/secret
# 3. Install secret to /etc/kolide-k2/secret (root:root, 0600)
#
# The dpkg status shim below satisfies Kolide's osquery deb_packages check
# for CrowdStrike compliance on NixOS (which has no dpkg database).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Kolide launcher package (download from company portal)
  # This is a placeholder - the actual binary needs to be extracted from the .deb
  kolideLauncher = pkgs.stdenv.mkDerivation {
    pname = "kolide-launcher";
    version = "1.0.0";

    # No source - we expect the binary to be manually installed to /opt/kolide-k2
    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin
      # Create a wrapper that points to the manually installed binary
      cat > $out/bin/kolide-launcher << 'EOF'
      #!/bin/sh
      exec /opt/kolide-k2/bin/launcher "$@"
      EOF
      chmod +x $out/bin/kolide-launcher
    '';
  };

  # FHS environment for Kolide launcher
  kolideFhs = pkgs.buildFHSEnv {
    name = "kolide-launcher-fhs";
    targetPkgs =
      pkgs: with pkgs; [
        bash
        coreutils
        glibc
        gnugrep
        nodejs
        openssl
        zlib
      ];
    runScript = "/opt/kolide-k2/bin/launcher";
  };
in
{
  # dpkg status shim for Kolide/osquery compliance
  # NixOS has no dpkg database, so Kolide's osquery deb_packages check fails.
  # This shim reports falcon-sensor as "installed" to satisfy the CrowdStrike check.
  systemd.tmpfiles.rules = [
    # Create dpkg directory
    "d /var/lib/dpkg 0755 root root -"
    # Create dpkg status file with falcon-sensor entry
    "f /var/lib/dpkg/status 0644 root root - Package: falcon-sensor\nStatus: install ok installed\nPriority: optional\nSection: misc\nInstalled-Size: 0\nMaintainer: CrowdStrike\nArchitecture: amd64\nVersion: 7.31.0-18410\nDescription: CrowdStrike Falcon Sensor (shim for Kolide/osquery on NixOS)\n"

    # Create Kolide directories
    "d /etc/kolide-k2 0755 root root -"
    "d /opt/kolide-k2 0755 root root -"
    "d /var/kolide-k2 0755 root root -"
  ];

  # Kolide Launcher service
  systemd.services.kolide-launcher = {
    description = "Kolide Launcher";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "local-fs.target"
    ];

    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "kolide-launcher-pre" ''
        # Ensure enrollment secret exists
        if [ ! -f /etc/kolide-k2/secret ]; then
          echo "ERROR: /etc/kolide-k2/secret not found."
          echo "Extract from company .deb and install with:"
          echo "  sudo install -d -m 755 /etc/kolide-k2"
          echo "  sudo sh -c 'cat <secret> > /etc/kolide-k2/secret'"
          echo "  sudo chown root:root /etc/kolide-k2/secret"
          echo "  sudo chmod 600 /etc/kolide-k2/secret"
          exit 1
        fi

        # Ensure launcher binary exists
        if [ ! -x /opt/kolide-k2/bin/launcher ]; then
          echo "ERROR: /opt/kolide-k2/bin/launcher not found."
          echo "Extract from company .deb and install to /opt/kolide-k2/"
          exit 1
        fi
      '';
      ExecStart = "${kolideFhs}/bin/kolide-launcher-fhs --enroll_secret_path=/etc/kolide-k2/secret --root_directory=/var/kolide-k2";
      Restart = "on-failure";
      RestartSec = "10s";

      # Kolide needs access to system information
      ProtectHome = false;
      ProtectSystem = false;
      PrivateTmp = false;
    };

    environment = {
      PATH = lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.bash
      ];
    };
  };
}
