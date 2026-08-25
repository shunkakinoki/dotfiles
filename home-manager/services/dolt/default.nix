{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isGalactica isKyber isMatic;
  homeDir = config.home.homeDirectory;
  repoDir = "${homeDir}/dotfiles";
  legacyBeadsDir = "${repoDir}/.beads";
  sharedServerDir = "${homeDir}/.beads/shared-server";
  beadsDir = "${sharedServerDir}/dolt";
  doltManifest = "${beadsDir}/beads_global/.dolt/noms/manifest";
  mirrorDir = "${homeDir}/.cache/beads-jsonl-mirror";
  remoteUrl = "https://github.com/shunkakinoki/beads";
  userEmail = "shunkakinoki@gmail.com";
  linearWorkspace = "shunkakinoki";
  linearTeamId = "679ab4ed-3df3-458d-8574-4962f3ebbf31";
  linearSyncIntervalSeconds = 900;
  federationSyncIntervalSeconds = 300;
  linearSyncPath = "${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
  enabled = isGalactica || isKyber || isMatic;
  linearSyncEnabled = isKyber;
  federationSyncEnabled = isGalactica || isMatic;
  # 2.2.2 fixes gitblobstore pending-write pruning that could publish a
  # manifest whose live archive later failed with "Blob not found".
  doltMinVersion = "2.2.2";
  startScript = pkgs.replaceVars ./start.sh {
    inherit beadsDir legacyBeadsDir;
    inherit (pkgs) dolt;
  };
  backupScript = pkgs.replaceVars ./backup-dolt-main.sh {
    inherit mirrorDir remoteUrl userEmail;
    inherit (pkgs) git;
  };
  linearSyncScript = pkgs.replaceVars ./linear-sync.sh {
    bd = "${homeDir}/.local/bin/bd";
    linear = "${homeDir}/.bun/install/global/node_modules/.bin/linear";
    inherit linearWorkspace linearTeamId;
    utilLinux = pkgs.util-linux;
    inherit (pkgs)
      coreutils
      curl
      dolt
      gawk
      jq
      ;
  };
  beadsLinearComplete = pkgs.writeShellScriptBin "beads-linear-complete" ''
    exec ${pkgs.bash}/bin/bash ${linearSyncScript} --complete "$@"
  '';
  federationSyncScript = pkgs.replaceVars ./federation-sync.sh {
    bd = "${homeDir}/.local/bin/bd";
    inherit (pkgs) coreutils;
  };
in
lib.mkIf enabled {
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.dolt.version doltMinVersion;
      message = "pkgs.dolt is ${pkgs.dolt.version}; needs >= ${doltMinVersion} for git+https push (beads_global GitHub backup). Update the dedicated nixpkgs-dolt pin.";
    }
  ];

  home.sessionVariables = {
    BEADS_DOLT_SHARED_SERVER = "1";
    BEADS_DOLT_SERVER_PORT = "3307";
    BEADS_SHARED_SERVER_DIR = sharedServerDir;
    DOLT_CLI_USER = "root";
    DOLT_CLI_PASSWORD = "";
    LINEAR_TEAM_ID = linearTeamId;
  };

  home.packages = lib.optional linearSyncEnabled beadsLinearComplete;

  launchd.agents.dolt = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${startScript}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      WorkingDirectory = repoDir;
      StandardOutPath = "/tmp/dolt.log";
      StandardErrorPath = "/tmp/dolt.error.log";
    };
  };

  # Mirror the live beads_global DB to refs/heads/main as JSONL so the data
  # is visible in the GitHub UI (Dolt's native push only writes refs/dolt/data).
  # Triggered by manifest changes inside dolt's noms store; throttled to avoid
  # hammering on rapid writes.
  launchd.agents.dolt-backup-main = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${backupScript}"
      ];
      WatchPaths = [ doltManifest ];
      ThrottleInterval = 60;
      RunAtLoad = false;
      KeepAlive = false;
      WorkingDirectory = repoDir;
      StandardOutPath = "/tmp/dolt-backup-main.log";
      StandardErrorPath = "/tmp/dolt-backup-main.error.log";
    };
  };

  launchd.agents.dolt-linear-sync = lib.mkIf (pkgs.stdenv.isDarwin && linearSyncEnabled) {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${linearSyncScript}"
      ];
      StartInterval = linearSyncIntervalSeconds;
      ThrottleInterval = linearSyncIntervalSeconds;
      RunAtLoad = true;
      WorkingDirectory = homeDir;
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = linearSyncPath;
        BEADS_DOLT_SHARED_SERVER = "1";
        BEADS_DOLT_SERVER_PORT = "3307";
        BEADS_SHARED_SERVER_DIR = sharedServerDir;
        DOLT_CLI_USER = "root";
        DOLT_CLI_PASSWORD = "";
        LINEAR_TEAM_ID = linearTeamId;
      };
      StandardOutPath = "/tmp/dolt-linear-sync.log";
      StandardErrorPath = "/tmp/dolt-linear-sync.error.log";
    };
  };

  launchd.agents.dolt-federation-sync = lib.mkIf (pkgs.stdenv.isDarwin && federationSyncEnabled) {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${federationSyncScript}"
      ];
      StartInterval = federationSyncIntervalSeconds;
      ThrottleInterval = federationSyncIntervalSeconds;
      RunAtLoad = true;
      WorkingDirectory = homeDir;
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = linearSyncPath;
        BEADS_DOLT_SHARED_SERVER = "1";
        BEADS_DOLT_SERVER_PORT = "3307";
        BEADS_SHARED_SERVER_DIR = sharedServerDir;
        DOLT_CLI_USER = "root";
        DOLT_CLI_PASSWORD = "";
      };
      StandardOutPath = "/tmp/dolt-federation-sync.log";
      StandardErrorPath = "/tmp/dolt-federation-sync.error.log";
    };
  };

  systemd.user.services.dolt = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Dolt SQL server for dotfiles beads";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${startScript}";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = repoDir;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.dolt-backup-main = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Push beads_global JSONL snapshot to GitHub main";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupScript}";
      WorkingDirectory = repoDir;
    };
  };

  systemd.user.paths.dolt-backup-main = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Watch dolt manifest and trigger JSONL backup";
    };
    Path = {
      PathChanged = doltManifest;
      Unit = "dolt-backup-main.service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.dolt-linear-sync = lib.mkIf (pkgs.stdenv.isLinux && linearSyncEnabled) {
    Unit = {
      Description = "Synchronize Beads with Linear";
      X-SwitchMethod = "restart";
      After = [
        "dolt.service"
        "network-online.target"
      ];
      Wants = [
        "dolt.service"
        "network-online.target"
      ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${linearSyncScript}";
      Environment = [
        "HOME=${homeDir}"
        "PATH=${linearSyncPath}"
        "BEADS_DOLT_SHARED_SERVER=1"
        "BEADS_DOLT_SERVER_PORT=3307"
        "BEADS_SHARED_SERVER_DIR=${sharedServerDir}"
        "DOLT_CLI_USER=root"
        "DOLT_CLI_PASSWORD="
        "LINEAR_TEAM_ID=${linearTeamId}"
      ];
    };
  };

  systemd.user.timers.dolt-linear-sync = lib.mkIf (pkgs.stdenv.isLinux && linearSyncEnabled) {
    Unit.Description = "Periodically synchronize Beads with Linear";
    Timer = {
      OnBootSec = "2min";
      OnCalendar = "*-*-* *:00/15:00";
      OnUnitActiveSec = "${toString linearSyncIntervalSeconds}s";
      Persistent = true;
      Unit = "dolt-linear-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.dolt-federation-sync =
    lib.mkIf (pkgs.stdenv.isLinux && federationSyncEnabled)
      {
        Unit = {
          Description = "Synchronize Beads with the Dolt remote";
          X-SwitchMethod = "restart";
          After = [
            "dolt.service"
            "network-online.target"
          ];
          Wants = [
            "dolt.service"
            "network-online.target"
          ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash ${federationSyncScript}";
          Environment = [
            "HOME=${homeDir}"
            "PATH=${linearSyncPath}"
            "BEADS_DOLT_SHARED_SERVER=1"
            "BEADS_DOLT_SERVER_PORT=3307"
            "BEADS_SHARED_SERVER_DIR=${sharedServerDir}"
            "DOLT_CLI_USER=root"
            "DOLT_CLI_PASSWORD="
          ];
        };
      };

  systemd.user.timers.dolt-federation-sync = lib.mkIf (pkgs.stdenv.isLinux && federationSyncEnabled) {
    Unit.Description = "Periodically synchronize Beads with the Dolt remote";
    Timer = {
      OnBootSec = "2min";
      OnCalendar = "*-*-* *:00/5:00";
      OnUnitActiveSec = "${toString federationSyncIntervalSeconds}s";
      Persistent = true;
      Unit = "dolt-federation-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
