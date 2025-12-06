{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start.sh}"
      ];
      Environment = {
        PATH = "${lib.makeBinPath [ pkgs.gnused ]}:/opt/homebrew/bin:/usr/local/bin";
      };
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi.log";
      StandardErrorPath = "/tmp/cliproxyapi.error.log";
    };
  };

  systemd.user.services.cliproxyapi = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "CLI Proxy API server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${lib.makeBinPath [ pkgs.gnused pkgs.bash ]}";
      ExecStart = "${pkgs.bash}/bin/bash ${./start.sh}";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
