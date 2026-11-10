{
  config,
  lib,
  pkgs,
  ...
}:
let
  maintainPath = "${
    lib.makeBinPath [
      pkgs.coreutils
      pkgs.findutils
      pkgs.sqlite
    ]
  }:${config.home.homeDirectory}/.cargo/bin:/usr/bin:/bin";
in
{
  home.activation.gitAiConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./config.json}" "${pkgs.git}/bin/git"
  '';

  launchd.agents.git-ai-maintain = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./maintain.sh}"
      ];
      EnvironmentVariables.PATH = maintainPath;
      StartInterval = 3600;
      ProcessType = "Background";
      StandardOutPath = "/tmp/git-ai-maintain.log";
      StandardErrorPath = "/tmp/git-ai-maintain.error.log";
    };
  };

  systemd.user.services.git-ai-maintain = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Flush git-ai logs with a bound and truncate its SQLite WAL";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${maintainPath}" ];
      Nice = 19;
      ExecStart = "${pkgs.bash}/bin/bash ${./maintain.sh}";
    };
  };

  systemd.user.timers.git-ai-maintain = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Timer for git-ai state maintenance";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
