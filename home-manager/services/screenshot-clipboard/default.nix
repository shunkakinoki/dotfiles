{ pkgs }:
{ config, ... }:
let
  inherit (pkgs) lib;
  logDir = "${config.home.homeDirectory}/Library/Logs";
in
{
  # A long-lived fswatch stream on ~/Desktop silently stops delivering events
  # after a while on macOS, so launchd's own WatchPaths triggers a one-shot
  # copy instead.
  launchd.agents.screenshot-clipboard = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./copy-latest.sh}"
      ];
      EnvironmentVariables = {
        PATH = "/usr/bin:/bin";
      };
      WatchPaths = [ "${config.home.homeDirectory}/Desktop" ];
      ThrottleInterval = 1;
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
