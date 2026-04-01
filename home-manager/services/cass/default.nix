{ pkgs, ... }:
let
  inherit (pkgs) lib;
  cass = "$HOME/.local/bin/cass";
in
{
  # Persistent daemon - keeps ML embedding model warm for fast semantic search
  launchd.agents.cass-daemon = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "${cass} daemon"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cass-daemon.log";
      StandardErrorPath = "/tmp/cass-daemon.error.log";
    };
  };

  # Daily index + analytics rebuild (runs at 4am)
  launchd.agents.cass-indexer = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./index.sh}"
      ];
      StartCalendarInterval = [
        {
          Hour = 4;
          Minute = 0;
        }
      ];
      StandardOutPath = "/tmp/cass-indexer.log";
      StandardErrorPath = "/tmp/cass-indexer.error.log";
    };
  };

  systemd.user.services.cass-daemon = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "cass semantic embedding daemon";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c '${cass} daemon'";
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.cass-indexer = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "cass daily index and analytics rebuild";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./index.sh}";
    };
  };

  systemd.user.timers.cass-indexer = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "cass daily index timer";
    };
    Timer = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
