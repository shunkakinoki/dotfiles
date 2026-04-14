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
{ pkgs, ... }:
let
  falcon = pkgs.callPackage ./falcon { };

  initScript = pkgs.writeScript "init-falcon" (
    builtins.readFile (
      pkgs.replaceVars ./falcon-init.sh {
        inherit (pkgs) e2fsprogs rsync;
        inherit falcon;
      }
    )
  );
in
{
  systemd.tmpfiles.rules = [
    "d /opt/CrowdStrike 0770 root root -"
  ];

  systemd.services.falcon-sensor = {
    description = "CrowdStrike Falcon Sensor";
    wantedBy = [ "multi-user.target" ];

    unitConfig.DefaultDependencies = false;
    # Start-limit directives belong in [Unit], not [Service].
    unitConfig.StartLimitIntervalSec = 0;
    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    before = [
      "sysinit.target"
      "shutdown.target"
    ];

    serviceConfig = {
      Type = "forking";
      PIDFile = "/run/falcond.pid";
      ExecStartPre = "${pkgs.bash}/bin/bash ${initScript}";
      ExecStart = "${falcon}/bin/fs-bash -c \"/opt/CrowdStrike/falcond\"";

      Restart = "on-failure";
      RestartSec = "15s";

      TimeoutStopSec = "60s";
      KillMode = "process";
      Delegate = true;
    };
  };
}
