# tmux session log backup to Google Drive via rclone
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.tmux-backup;

  backupScript = pkgs.writeShellScript "tmux-backup" ''
    ${pkgs.rclone}/bin/rclone sync "${cfg.localPath}/" "${cfg.remote}:${cfg.remotePath}/" --log-level INFO
  '';
in
{
  options.modules.tmux-backup = {
    enable = mkEnableOption "tmux session log backup to Google Drive";

    remote = mkOption {
      type = types.str;
      default = "gdrive";
      description = "rclone remote name for Google Drive";
    };

    remotePath = mkOption {
      type = types.str;
      default = "tmux-logs";
      description = "Destination path on the remote";
    };

    localPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.local/share/tmux";
      description = "Local tmux log directory to sync";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.rclone ];

    launchd.agents.tmux-backup = mkIf pkgs.stdenv.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${backupScript}" ];
        RunAtLoad = true;
        StartInterval = 3600;
        StandardOutPath = "/tmp/tmux-backup.log";
        StandardErrorPath = "/tmp/tmux-backup.error.log";
      };
    };

    systemd.user.services.tmux-backup = mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "Backup tmux session logs to Google Drive";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${backupScript}";
      };
    };

    systemd.user.timers.tmux-backup = mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "Timer for tmux session log backup";
      };
      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
