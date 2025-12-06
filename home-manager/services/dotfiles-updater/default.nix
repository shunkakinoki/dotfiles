{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.dotfiles-updater = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./update.sh}"
      ];
      Environment = {
        PATH = "${
          lib.makeBinPath [
            pkgs.git
            pkgs.bash
            pkgs.coreutils
          ]
        }:/opt/homebrew/bin:/usr/local/bin";
      };
      StartCalendarInterval = [
        {
          Hour = 0;
          Minute = 0;
        }
      ];
      StandardOutPath = "/tmp/dotfiles-updater.log";
      StandardErrorPath = "/tmp/dotfiles-updater.error.log";
    };
  };

  systemd.user.services.dotfiles-updater = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Dotfiles auto-updater service";
    };
    Service = {
      Type = "oneshot";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.git
          pkgs.bash
        ]
      }";
      ExecStart = "${./update.sh}";
    };
  };

  systemd.user.timers.dotfiles-updater = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer for dotfiles auto-updater";
    };
    Timer = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
