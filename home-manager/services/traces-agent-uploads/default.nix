{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  runner = pkgs.writeShellApplication {
    name = "traces-agent-uploads";
    runtimeInputs = [
      pkgs.git
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      exec python3 ${./queue.py} --state-dir ${lib.escapeShellArg "${homeDir}/.local/state/traces-agent-uploads"} "$@"
    '';
  };
in
lib.mkIf inputs.host.isKyber {
  home.file.".local/libexec/traces-agent-uploads".source = "${runner}/bin/traces-agent-uploads";

  systemd.user.slices.traces-uploads.Slice = {
    IOAccounting = true;
    IOReadBandwidthMax = "/ 5M";
    IOWriteBandwidthMax = "/ 2M";
    IOReadIOPSMax = "/ 100";
    IOWriteIOPSMax = "/ 50";
    CPUQuota = "100%";
    MemoryHigh = "2G";
    MemoryMax = "4G";
    TasksMax = 128;
  };

  systemd.user.services.traces-agent-uploads = {
    Unit.Description = "Drain coalesced agent trace uploads";
    Service = {
      Type = "exec";
      ExecStart = "${runner}/bin/traces-agent-uploads drain";
      Slice = "traces-uploads.slice";
      TimeoutStartSec = 15;
      TimeoutStopSec = 15;
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.bun/install/global/node_modules/.bin:${config.home.profileDirectory}/bin:/usr/bin:/bin"
      ];
    };
  };

  # Recover a missed wakeup or a timed-out upload even after the final hook.
  systemd.user.timers.traces-agent-uploads = {
    Unit.Description = "Retry queued agent trace uploads";
    Timer = {
      OnStartupSec = "1m";
      OnUnitInactiveSec = "1m";
      Unit = "traces-agent-uploads.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
