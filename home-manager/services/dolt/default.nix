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
  beadsDir = "${repoDir}/.beads";
  doltManifest = "${beadsDir}/beads_global/.dolt/noms/manifest";
  mirrorDir = "${homeDir}/.cache/beads-jsonl-mirror";
  remoteUrl = "https://github.com/shunkakinoki/beads";
  userEmail = "shunkakinoki@gmail.com";
  enabled = isKyber || isGalactica;
  # 1.86+ adds the git+https:// remote scheme used by the beads_global GitHub backup.
  doltMinVersion = "1.86";
  startScript = pkgs.replaceVars ./start.sh {
    inherit beadsDir;
    inherit (pkgs) dolt;
  };
  backupScript = pkgs.replaceVars ./backup-dolt-main.sh {
    inherit mirrorDir remoteUrl userEmail;
    inherit (pkgs) git;
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
}
