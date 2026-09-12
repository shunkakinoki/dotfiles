{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  enabled = config.services.traces-agent-uploads.enable;
  disabledHook = pkgs.writeShellScript "traces-agent-uploads-disabled" "exit 0";
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
{
  options.services.traces-agent-uploads.enable = lib.mkEnableOption "automatic agent trace uploads";

  config = lib.mkIf inputs.host.isKyber {
    # Keep the dispatcher installed while disabled so hooks cannot fall through
    # to the unmanaged uploader. Existing queued requests remain on disk.
    home.file.".local/libexec/traces-agent-uploads".source =
      if enabled then "${runner}/bin/traces-agent-uploads" else disabledHook;

    systemd.user = lib.mkIf enabled {
      slices.traces-uploads.Slice = {
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

      services.traces-agent-uploads = {
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
      timers.traces-agent-uploads = {
        Unit.Description = "Retry queued agent trace uploads";
        Timer = {
          OnStartupSec = "1m";
          OnUnitInactiveSec = "1m";
          Unit = "traces-agent-uploads.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
