{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.screenshot-clipboard = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./watch.sh}"
      ];
      EnvironmentVariables = {
        PATH = "${
          lib.makeBinPath [
            pkgs.fswatch
          ]
        }:/usr/bin:/bin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardOutPath = "/tmp/screenshot-clipboard.log";
      StandardErrorPath = "/tmp/screenshot-clipboard.error.log";
    };
  };

  systemd.user.services.screenshot-clipboard = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Auto-copy screenshots to clipboard";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.fswatch
          pkgs.wl-clipboard
          pkgs.xclip
        ]
      }";
      ExecStart = "${pkgs.bash}/bin/bash ${./watch.sh}";
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
