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
    openssl = "${pkgs.openssl}/bin/openssl";
  };
  dockerStartScript = pkgs.replaceVars ../cpa-manager-plus/docker-start.sh {
    inherit (pkgs) bash;
    docker = "${pkgs.docker}/bin/docker";
    start_script = startScript;
  };
in
lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && host.isKyber) {
  systemd.user.services.paperclip = {
    Unit = {
      Description = "Paperclip agent orchestration server";
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
      # Paperclip waits up to 30s for running adapters to settle on shutdown.
      TimeoutStopSec = 90;
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
