# CrowdStrike Falcon sensor configuration for NixOS
#
# Prerequisites (manual steps):
# 1. Obtain the Falcon sensor .deb from IT
# 2. Place it at: /etc/nixos/falcon-sensor.deb
#    sudo cp ~/Downloads/falcon-sensor*.deb /etc/nixos/falcon-sensor.deb
# 3. Create /etc/falcon-sensor.env with: FALCON_CID=<your-cid>
#
# This module is only imported if /etc/nixos/falcon-sensor.deb exists.
#
# Based on: https://github.com/taylanpince/nixos-config
{ pkgs, lib, ... }:
let
  falcon = pkgs.callPackage ./falcon { };

  initScript = pkgs.writeScript "init-falcon" ''
    #!${pkgs.bash}/bin/sh
    set -euo pipefail

    # Only initialize if not already set up (CrowdStrike protects its files)
    if [ ! -f /opt/CrowdStrike/falcond ]; then
      install -d -m 0770 /opt/CrowdStrike
      cp -a ${falcon}/opt/CrowdStrike/. /opt/CrowdStrike/
      chown -R root:root /opt/CrowdStrike
    fi

    # load CID from /etc/falcon-sensor.env (root-only)
    . /etc/falcon-sensor.env

    # set CID via falconctl inside FHS env
    ${falcon}/bin/fs-bash -c "/opt/CrowdStrike/falconctl -s -f --cid=\"$FALCON_CID\""

    # sanity print
    ${falcon}/bin/fs-bash -c "/opt/CrowdStrike/falconctl -g --cid"
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /opt/CrowdStrike 0770 root root -"
  ];

  systemd.services.falcon-sensor = {
    description = "CrowdStrike Falcon Sensor";
    wantedBy = [ "multi-user.target" ];

    unitConfig.DefaultDependencies = false;
    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    before = [
      "sysinit.target"
      "shutdown.target"
    ];

    serviceConfig = {
      Type = "forking";
      PIDFile = "/run/falcond.pid";
      ExecStartPre = initScript;
      ExecStart = "${falcon}/bin/fs-bash -c \"/opt/CrowdStrike/falcond\"";

      Restart = "on-failure";
      RestartSec = "15s";

      # Avoid systemd giving up during flapping
      StartLimitIntervalSec = 0;

      TimeoutStopSec = "60s";
      KillMode = "process";
      Delegate = true;
    };
  };
}
