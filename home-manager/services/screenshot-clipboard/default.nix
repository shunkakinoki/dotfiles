{ pkgs }:
{ config, ... }:
let
  inherit (pkgs) lib;
  logDir = "${config.home.homeDirectory}/Library/Logs";
in
{
  # A long-lived fswatch (FSEvents) stream on ~/Desktop silently stops
  # delivering events after a while, and launchd WatchPaths is throttled to
  # seconds and drops triggers. A kqueue vnode watch on the directory itself
  # fires within milliseconds and does not go through FSEvents.
  launchd.agents.screenshot-clipboard = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.python3}/bin/python3"
        "${./kqueue-watch.py}"
        "${pkgs.bash}/bin/bash"
        "${./copy-latest.sh}"
      ];
      EnvironmentVariables = {
        PATH = "/usr/bin:/bin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      ProcessType = "Interactive";
      StandardOutPath = "${logDir}/screenshot-clipboard.log";
      StandardErrorPath = "${logDir}/screenshot-clipboard.error.log";
    };
  };

  systemd.user.services.screenshot-clipboard = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
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
