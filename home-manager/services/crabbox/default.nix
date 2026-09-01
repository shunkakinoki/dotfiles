{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs.host) isKyber;
  homeDir = config.home.homeDirectory;
  dataDir = "${homeDir}/.local/share/crabbox/postgres";
  socketDir = "${homeDir}/.local/share/crabbox/postgres-socket";
  coordinatorBin = "${homeDir}/ghq/github.com/openclaw/crabbox/worker/dist-node/crabbox-coordinator";
  postgresPort = "55432";
  coordinatorPort = "18080";
  initPostgres = pkgs.replaceVars ./init-postgres.sh {
    inherit dataDir socketDir;
    databaseAdmin = config.home.username;
    initdb = "${pkgs.postgresql_18}/bin/initdb";
  };
  startCoordinator = pkgs.replaceVars ./start.sh {
    inherit
      coordinatorBin
      coordinatorPort
      homeDir
      postgresPort
      socketDir
      ;
    inherit (pkgs)
      coreutils
      gnugrep
      openssl
      postgresql_18
      ;
  };
  checkCoordinator = pkgs.replaceVars ./health-check.sh {
    inherit coordinatorPort;
    inherit (pkgs) coreutils curl;
  };
in
lib.mkIf (isKyber && pkgs.stdenv.hostPlatform.isLinux) {
  systemd.user.services.crabbox-postgres = {
    Unit = {
      Description = "Local PostgreSQL for Crabbox";
      Documentation = [ "https://github.com/openclaw/crabbox/blob/main/docs/infrastructure.md" ];
      After = [ "local-fs.target" ];
      X-SwitchMethod = "restart";
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.bash}/bin/bash ${initPostgres}";
      ExecStart = "${pkgs.postgresql_18}/bin/postgres -D ${dataDir} -h 127.0.0.1 -p ${postgresPort} -k ${socketDir}";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = 30;
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.crabbox = {
    Unit = {
      Description = "Crabbox Node coordinator";
      Documentation = [ "https://github.com/openclaw/crabbox/blob/main/docs/infrastructure.md" ];
      After = [
        "crabbox-postgres.service"
        "network-online.target"
      ];
      Requires = [ "crabbox-postgres.service" ];
      Wants = [ "network-online.target" ];
      X-SwitchMethod = "restart";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${startCoordinator}";
      ExecStartPost = "${pkgs.bash}/bin/bash ${checkCoordinator}";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = 120;
      # Upstream drains for up to 120 seconds by default.
      TimeoutStopSec = 150;
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/share/fnm/current/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
