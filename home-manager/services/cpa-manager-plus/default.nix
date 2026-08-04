{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs) host;
  startScript = pkgs.replaceVars ./start.sh {
    docker = "${pkgs.docker}/bin/docker";
  };
  dockerStartScript = pkgs.replaceVars ./docker-start.sh {
    inherit (pkgs) bash;
    docker = "${pkgs.docker}/bin/docker";
    start_script = startScript;
  };
in
lib.mkIf (pkgs.stdenv.isLinux && host.isKyber) {
  systemd.user.services.cpa-manager-plus = {
    Unit = {
      Description = "CPA Manager Plus analytics and management server";
      After = [
        "network-online.target"
        "docker.service"
        "cliproxyapi.service"
      ];
      Wants = [
        "network-online.target"
        "docker.service"
        "cliproxyapi.service"
      ];
      X-SwitchMethod = "restart";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 10;
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${dockerStartScript}";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.docker
        ]
      }:/usr/bin:/usr/sbin";
      TimeoutStopSec = 45;
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
