# Google Drive backup via rclone
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.gdrive-backup;

  backupScript = pkgs.writeShellScript "gdrive-backup" ''
    ${pkgs.rclone}/bin/rclone sync "${cfg.localPath}/" "${cfg.remote}:${cfg.remotePath}/" \
      ${optionalString (cfg.clientId != "") ''--drive-client-id "${cfg.clientId}"''} \
      ${optionalString (cfg.clientSecret != "") ''--drive-client-secret "${cfg.clientSecret}"''} \
      ${optionalString (cfg.scope != "") ''--drive-scope "${cfg.scope}"''} \
      --log-level INFO
  '';
in
{
  options.modules.gdrive-backup = {
    enable = mkEnableOption "Google Drive backup via rclone";

    remote = mkOption {
      type = types.str;
      default = "gdrive";
      description = "rclone remote name for Google Drive";
    };

    remotePath = mkOption {
      type = types.str;
      default = "backups";
      description = "Destination path on Google Drive";
    };

    localPath = mkOption {
      type = types.str;
      description = "Local directory to sync to Google Drive";
    };

    clientId = mkOption {
      type = types.str;
      default = "";
      description = "Google Drive OAuth2 client ID (overrides rclone remote config)";
    };

    clientSecret = mkOption {
      type = types.str;
      default = "";
      description = "Google Drive OAuth2 client secret (overrides rclone remote config)";
    };

    scope = mkOption {
      type = types.enum [
        ""
        "drive"
        "drive.readonly"
        "drive.file"
        "drive.appfolder"
        "drive.metadata.readonly"
      ];
      default = "drive";
      description = "Google Drive access scope for rclone";
    };

    interval = mkOption {
      type = types.int;
      default = 3600;
      description = "Backup interval in seconds (Darwin launchd) or use OnCalendar for systemd";
    };

    onCalendar = mkOption {
      type = types.str;
      default = "hourly";
      description = "Systemd OnCalendar expression for backup schedule (Linux)";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.rclone ];

    launchd.agents.gdrive-backup = mkIf pkgs.stdenv.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${backupScript}" ];
        RunAtLoad = true;
        StartInterval = cfg.interval;
        StandardOutPath = "/tmp/gdrive-backup.log";
        StandardErrorPath = "/tmp/gdrive-backup.error.log";
      };
    };

    systemd.user.services.gdrive-backup = mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "Backup ${cfg.localPath} to Google Drive (${cfg.remote}:${cfg.remotePath})";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${backupScript}";
      };
    };

    systemd.user.timers.gdrive-backup = mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "Timer for Google Drive backup";
      };
      Timer = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
