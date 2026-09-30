{ inputs, pkgs, ... }:
let
  inherit (pkgs) lib;
  canonicalHost =
    if inputs.host.isKyber then
      "kyber"
    else if inputs.host.isMatic then
      "matic"
    else if inputs.host.isKamino then
      inputs.host.nodeName
    else
      null;
in
{
  launchd.agents.dotfiles-updater = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./update.sh}"
      ];
      # launchd starts agents with a bare PATH. install.sh needs the Nix daemon's
      # client and the system make, curl, and sudo; without them it tries to
      # reinstall Nix and fails. AUTOMATED_UPDATE keeps an unattended run from
      # rewriting flake.lock, as on Linux.
      Environment = {
        PATH = "${
          lib.makeBinPath [
            pkgs.git
            pkgs.bash
            pkgs.coreutils
          ]
        }:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        AUTOMATED_UPDATE = "true";
      };
      StartInterval = 10800;
      StandardOutPath = "/tmp/dotfiles-updater.log";
      StandardErrorPath = "/tmp/dotfiles-updater.error.log";
    };
  };

  systemd.user.services.dotfiles-updater = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Dotfiles auto-updater service";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.curl
            pkgs.docker
            pkgs.gawk
            pkgs.git
            pkgs.gnugrep
            pkgs.gnumake
            pkgs.gnused
            pkgs.nix
            pkgs.sudo
            pkgs.systemd
            pkgs.which
          ]
        }"
        "AUTOMATED_UPDATE=true"
      ]
      ++ lib.optional (canonicalHost != null) "HOST=${canonicalHost}";
      Nice = 19;
      IOSchedulingPriority = 7;
      # %t matches the XDG_RUNTIME_DIR lock that `make switch` holds; skip this run instead of racing it.
      ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 %t/dotfiles-switch.lock ${./update.sh}";
    };
  };

  systemd.user.timers.dotfiles-updater = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Timer for dotfiles auto-updater";
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
