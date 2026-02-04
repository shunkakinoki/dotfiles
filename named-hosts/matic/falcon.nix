# CrowdStrike Falcon sensor configuration for NixOS
#
# Prerequisites (manual steps):
# 1. Obtain the Falcon sensor .deb from IT
# 2. Create /etc/falcon-sensor.env with: FALCON_CID=<your-cid>
# 3. Extract and place sensor files (see README for details)
#
# Based on: https://gist.github.com/klDen/c90d9798828e31fecbb603f85e27f4f1
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # FHS environment for CrowdStrike Falcon
  # NixOS doesn't have standard /opt paths, so we create an FHS-compatible environment
  falconFhs = pkgs.buildFHSEnv {
    name = "falcon-sensor-fhs";
    targetPkgs =
      pkgs: with pkgs; [
        # Runtime dependencies for Falcon sensor
        bash
        coreutils
        curl
        glibc
        gnugrep
        libnl
        openssl
        zlib
      ];
    runScript = "/opt/CrowdStrike/falcond";
  };
in
{
  # Create necessary directories and symlinks for CrowdStrike
  systemd.tmpfiles.rules = [
    # Create /opt/CrowdStrike directory
    "d /opt/CrowdStrike 0770 root root -"
  ];

  # CrowdStrike Falcon sensor service
  systemd.services.falcon-sensor = {
    description = "CrowdStrike Falcon Sensor";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "local-fs.target"
    ];

    # Load the CID from environment file
    serviceConfig = {
      Type = "forking";
      ExecStartPre = pkgs.writeShellScript "falcon-sensor-pre" ''
        # Ensure CID is configured
        if [ ! -f /etc/falcon-sensor.env ]; then
          echo "ERROR: /etc/falcon-sensor.env not found. Create it with FALCON_CID=<your-cid>"
          exit 1
        fi

        # Source the CID
        source /etc/falcon-sensor.env
        if [ -z "$FALCON_CID" ]; then
          echo "ERROR: FALCON_CID not set in /etc/falcon-sensor.env"
          exit 1
        fi

        # Set the CID if not already set
        if ! /opt/CrowdStrike/falconctl -g --cid | grep -q "$FALCON_CID"; then
          /opt/CrowdStrike/falconctl -s --cid="$FALCON_CID"
        fi
      '';
      ExecStart = "${falconFhs}/bin/falcon-sensor-fhs";
      ExecStop = "/bin/kill -TERM $MAINPID";
      Restart = "on-failure";
      RestartSec = "10s";
      KillMode = "process";

      # Security hardening
      ProtectHome = false;
      ProtectSystem = false;
      PrivateTmp = false;
    };

    # Add required tools to PATH
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];
  };

  # Required kernel modules for Falcon sensor
  boot.kernelModules = [ "falcon" ];
}
