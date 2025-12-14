{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.code-syncer = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./sync.sh}"
      ];
      Environment = {
        PATH = "${lib.makeBinPath [
          pkgs.fswatch
        ]}";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/code-syncer.log";
      StandardErrorPath = "/tmp/code-syncer.error.log";
    };
  };

  systemd.user.services.code-syncer = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "VS Code settings syncer";
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.inotify-tools
        ]
      }";
      ExecStart = "${pkgs.bash}/bin/bash ${./sync.sh}";
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
