{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs) host;
  version = pkgs.crabbox.version;
  sourceRevision = "8ba71f913bbe57285ae29af45ef0d8ec6712477d";
  homeDir = config.home.homeDirectory;

  startScript = pkgs.replaceVars ./start.sh {
    curl = "${pkgs.curl}/bin/curl";
    docker = "${pkgs.docker}/bin/docker";
    openssl = "${pkgs.openssl}/bin/openssl";
    source_revision = sourceRevision;
    inherit version;
  };

  dockerStartScript = pkgs.replaceVars ./docker-start.sh {
    inherit (pkgs) bash docker;
    start_script = startScript;
  };
in
lib.mkIf (pkgs.stdenv.isLinux && host.isKyber) {
  systemd.user.services.crabbox = {
    Unit = {
      Description = "Crabbox remote execution coordinator";
      Documentation = "https://crabbox.sh/";
      After = [
        "network-online.target"
        "docker.service"
      ];
      Wants = [
        "network-online.target"
        "docker.service"
      ];
      X-SwitchMethod = "restart";
      StartLimitIntervalSec = 600;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${dockerStartScript}";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.curl
            pkgs.docker
            pkgs.gnugrep
            pkgs.openssl
          ]
        }:/usr/bin:/usr/sbin"
      ];
      Restart = "always";
      RestartSec = 10;
      TimeoutStartSec = 900;
      TimeoutStopSec = 150;
      StandardOutput = "journal";
      StandardError = "journal";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
