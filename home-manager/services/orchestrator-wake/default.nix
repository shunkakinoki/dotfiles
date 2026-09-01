{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs.host) isGalactica isMatic;
  homeDir = config.home.homeDirectory;
  enabled = isGalactica || isMatic;
  lane = if isMatic then "matic_orchestrator" else "galactica_orchestrator";
  wakeScript = "${homeDir}/ghq/github.com/shunkakinokisoftware/shunkakinokisoftware/scripts/herdr-orchestrator-wake.ts";
  servicePath = lib.makeBinPath [
    pkgs.bun
    pkgs.coreutils
  ];
in
lib.mkIf enabled {
  launchd.agents.orchestrator-wake = lib.mkIf isGalactica {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bun}/bin/bun"
        "run"
        wakeScript
        lane
        "--tag"
        "via-home-manager"
      ];
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = "${servicePath}:${homeDir}/.local/bin:${homeDir}/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
      };
      RunAtLoad = true;
      StartInterval = 600;
      StandardOutPath = "/tmp/orchestrator-wake.log";
      StandardErrorPath = "/tmp/orchestrator-wake.error.log";
    };
  };

  systemd.user.services.orchestrator-wake = lib.mkIf isMatic {
    Unit = {
      Description = "Wake the local Herdr orchestrator";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${servicePath}:${homeDir}/.local/bin:${homeDir}/.bun/bin:/run/current-system/sw/bin:/usr/bin:/bin"
      ];
      ExecStart = "${pkgs.bun}/bin/bun run ${wakeScript} ${lane} --tag via-home-manager";
    };
  };

  systemd.user.timers.orchestrator-wake = lib.mkIf isMatic {
    Unit = {
      Description = "Wake the local Herdr orchestrator every ten minutes";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "10min";
      AccuracySec = "1min";
      Unit = "orchestrator-wake.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
