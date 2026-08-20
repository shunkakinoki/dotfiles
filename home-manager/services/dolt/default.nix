{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isKyber isGalactica;
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
  linearSyncIntervalSeconds = 300;
  linearSyncPath = "${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
  enabled = isKyber || isGalactica;
  # 1.86+ adds the git+https:// remote scheme used by the beads_global GitHub backup.
  doltMinVersion = "1.86";
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
    inherit repoDir linearWorkspace linearTeamId;
    inherit (pkgs) coreutils gawk jq;
  };
in
lib.mkIf enabled {
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.dolt.version doltMinVersion;
      message = "pkgs.dolt is ${pkgs.dolt.version}; needs >= ${doltMinVersion} for git+https push (beads_global GitHub backup). Run 'nix flake update nixpkgs-unstable'.";
    }
  ];

  home.sessionVariables = {
    BEADS_DOLT_SHARED_SERVER = "1";
    BEADS_DOLT_SERVER_PORT = "3307";
    BEADS_SHARED_SERVER_DIR = sharedServerDir;
    DOLT_CLI_USER = "root";
    DOLT_CLI_PASSWORD = "";
  };

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

  launchd.agents.dolt-linear-sync = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${linearSyncScript}"
      ];
      StartInterval = linearSyncIntervalSeconds;
      ThrottleInterval = linearSyncIntervalSeconds;
      RunAtLoad = true;
      WorkingDirectory = repoDir;
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

  systemd.user.services.dolt-linear-sync = lib.mkIf pkgs.stdenv.isLinux {
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

  systemd.user.timers.dolt-linear-sync = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Periodically synchronize Beads with Linear";
    Timer = {
      OnBootSec = "2min";
      OnCalendar = "*-*-* *:00/5:00";
      OnUnitActiveSec = "${toString linearSyncIntervalSeconds}s";
      Persistent = true;
      Unit = "dolt-linear-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
