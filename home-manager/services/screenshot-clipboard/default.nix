{ pkgs }:
{ config, ... }:
let
  inherit (pkgs) lib;
  logDir = "${config.home.homeDirectory}/Library/Logs";
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
      # Restart on crash/non-zero exit, but throttle to avoid a tight loop if
      # a prereq (fswatch, helper script) is missing during early activation.
      KeepAlive = {
        SuccessfulExit = false;
      };
      ThrottleInterval = 30;
      ProcessType = "Background";
      StandardOutPath = "${logDir}/screenshot-clipboard.log";
      StandardErrorPath = "${logDir}/screenshot-clipboard.error.log";
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
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
