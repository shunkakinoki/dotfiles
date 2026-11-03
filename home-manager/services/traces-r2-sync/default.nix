{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs) host;
  # Every fleet host that holds a scoped agents-prd identity can read the
  # bucket credentials, so the identity is the fleet membership signal.
  enabled = config.agentsPrd.envFile != null;
  uploadScript = pkgs.replaceVars ./upload.sh {
    host = host.nodeName;
  };
in
{
  config = lib.mkIf enabled {
    systemd.user.services.traces-r2-sync = {
      Unit = {
        Description = "Copy agent session transcripts to the traces R2 bucket";
        After = [ "agenix.service" ];
        Wants = [ "agenix.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${uploadScript}";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.doppler
              pkgs.jq
              pkgs.rclone
            ]
          }"
          "TRACES_R2_IDENTITY_FILE=${config.agentsPrd.envFile}"
        ];
        # Lanes share these disks; the upload yields to them.
        IOAccounting = true;
        IOWeight = 10;
        Nice = 10;
        TimeoutStartSec = "1h";
        UMask = "0077";
      };
    };

    systemd.user.timers.traces-r2-sync = {
      Unit.Description = "Hourly agent transcript upload to R2";
      Timer = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1h";
        # Spread the fleet's uploads instead of starting every host together.
        RandomizedDelaySec = "10min";
        Unit = "traces-r2-sync.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
