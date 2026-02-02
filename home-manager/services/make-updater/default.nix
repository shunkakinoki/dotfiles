{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.make-updater = lib.mkIf pkgs.stdenv.isDarwin {
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
            pkgs.gnumake
          ]
        }:/opt/homebrew/bin:/usr/local/bin";
      };
      StartInterval = 10800;
      StandardOutPath = "/tmp/make-updater.log";
      StandardErrorPath = "/tmp/make-updater.error.log";
    };
  };

  systemd.user.services.make-updater = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Make update service";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.cargo
            pkgs.coreutils
            pkgs.curl
            pkgs.gawk
            pkgs.git
            pkgs.gnumake
            pkgs.gnused
            pkgs.go
            pkgs.nix
            pkgs.sudo
            pkgs.which
          ]
        }"
        "AUTOMATED_UPDATE=true"
      ];
      ExecStart = "${./update.sh}";
    };
  };

  systemd.user.timers.make-updater = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer for make update";
    };
    Timer = {
      OnCalendar = "*-*-* 00/3:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
