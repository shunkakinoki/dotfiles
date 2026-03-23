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
      StartInterval = 16200;
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
            pkgs.autoconf
            pkgs.bash
            pkgs.binutils
            pkgs.cargo
            pkgs.coreutils
            pkgs.curl
            pkgs.elixir
            pkgs.gawk
            pkgs.gcc
            pkgs.ghq
            pkgs.git
            pkgs.gnumake
            pkgs.gnused
            pkgs.go
            pkgs.libtool
            pkgs.nix
            pkgs.openssl.dev
            pkgs.pkg-config
            pkgs.rustup
            pkgs.sudo
            pkgs.which
          ]
        }"
        "AUTOMATED_UPDATE=true"
        "RUSTUP_HOME=%h/.rustup"
        "CARGO_HOME=%h/.cargo"
      ];
      Nice = 19;
      IOSchedulingPriority = 7;
      ExecStart = "${./update.sh}";
    };
  };

  systemd.user.timers.make-updater = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Timer for make update";
    };
    Timer = {
      OnCalendar = "*-*-* 01/3:30:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
