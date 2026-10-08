{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs.host) isKamino nodeName;
  homeDir = config.home.homeDirectory;
  enabled =
    isKamino
    && builtins.elem nodeName [
      "kamino8"
      "kamino9"
      "kamino10"
    ];
  runWarm = pkgs.replaceVars ./run.sh {
    inherit (pkgs) findutils jq;
    bunBin = "${homeDir}/.bun/bin/bun";
  };
in
lib.mkIf enabled {
  systemd.user.services.ci-box-warm = {
    Unit = {
      Description = "Warm the CI box Turbo cache from origin/main";
      X-SwitchMethod = "restart";
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = homeDir;
      Environment = [
        "PATH=${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      ExecStart = "${pkgs.bash}/bin/bash ${runWarm}";
      Nice = 10;
    };
  };

  systemd.user.timers.ci-box-warm = {
    Unit = {
      Description = "Warm the CI box Turbo cache after origin/main moves";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitInactiveSec = "5min";
      RandomizedDelaySec = "2min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
