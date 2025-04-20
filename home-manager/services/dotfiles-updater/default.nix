{ pkgs }:
{
  systemd.user.services.dotfiles-updater = {
    Unit = {
      Description = "Dotfiles auto-updater service";
    };
    Service = {
      Type = "oneshot";
      Environment = "PATH=${pkgs.lib.makeBinPath (with pkgs; [git bash])}";
      ExecStart = "${./update.sh}";
    };
  };

  systemd.user.timers.dotfiles-updater = {
    Unit = {
      Description = "Timer for dotfiles auto-updater";
    };
    Timer = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
