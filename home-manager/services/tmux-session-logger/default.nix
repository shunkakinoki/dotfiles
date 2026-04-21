{ pkgs, ... }:
let
  inherit (pkgs) lib;
  sessionLoggerScript = ../../programs/tmux/session-logger.sh;
  servicePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.tmux
  ];
in
{
  launchd.agents.tmux-session-logger = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${sessionLoggerScript}"
      ];
      Environment = {
        PATH = "${servicePath}:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      RunAtLoad = true;
      StartInterval = 30;
      StandardOutPath = "/tmp/tmux-session-logger.log";
      StandardErrorPath = "/tmp/tmux-session-logger.error.log";
    };
  };

  systemd.user.services.tmux-session-logger = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Persist tmux pane history snapshots";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = "PATH=${servicePath}";
      ExecStart = "${pkgs.bash}/bin/bash ${sessionLoggerScript}";
    };
  };

  systemd.user.timers.tmux-session-logger = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer for tmux session history logging";
    };
    Timer = {
      OnBootSec = "1s";
      OnUnitActiveSec = "30s";
      AccuracySec = "1s";
      Unit = "tmux-session-logger.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
