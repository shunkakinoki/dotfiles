{
  config,
  lib,
  pkgs,
  ...
}:
let
  binPath = lib.makeBinPath [
    pkgs.bun
    pkgs.bash
    pkgs.coreutils
  ];
  activationPath = lib.concatStringsSep ":" [
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    (lib.makeBinPath [
      pkgs.coreutils
      pkgs.gawk
    ])
    "/usr/bin"
    "/bin"
  ];
  # Every 3 hours, aligned to the wall clock.
  calendarHours = [
    0
    3
    6
    9
    12
    15
    18
    21
  ];
  cronCommand = lib.concatStringsSep " " [
    "env"
    "HOME=${lib.escapeShellArg config.home.homeDirectory}"
    "PATH=${lib.escapeShellArg binPath}"
    "${pkgs.bash}/bin/bash"
    "${./submit.sh}"
    ">>/tmp/tokscale.log"
    "2>>/tmp/tokscale.error.log"
  ];
in
{
  # macOS (launchd)
  launchd.agents.tokscale = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./submit.sh}"
      ];
      EnvironmentVariables = {
        PATH = binPath + ":/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StartCalendarInterval = map (hour: {
        Hour = hour;
        Minute = 0;
      }) calendarHours;
      StandardOutPath = "/tmp/tokscale.log";
      StandardErrorPath = "/tmp/tokscale.error.log";
    };
  };

  # Linux (cron)
  home.activation.installTokscaleCron = lib.mkIf pkgs.stdenv.isLinux (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/env PATH=${lib.escapeShellArg activationPath} \
        ${pkgs.bash}/bin/bash "${./activate-cron.sh}" ${lib.escapeShellArg cronCommand}
    ''
  );
}
