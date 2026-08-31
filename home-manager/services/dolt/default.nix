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
  clientEnabled = isGalactica || isKyber || isMatic;
  # bd opens its store with dozens of sequential round trips per invocation, so
  # a direct client of Kyber's Chicago server costs seconds per command on the
  # ~260ms agent hosts. Every host serves its own Dolt and converges through the
  # shared remote instead.
  serverEnabled = clientEnabled;
  # Kyber alone publishes the shared history to the configured remotes.
  publisherEnabled = isKyber;
  doltServerHost = "127.0.0.1";
  beadsClientEnvironment = {
    BEADS_DOLT_AUTO_START = "0";
    BEADS_DOLT_SERVER_MODE = "1";
    BEADS_DOLT_SERVER_HOST = doltServerHost;
    BEADS_DOLT_SERVER_PORT = "3307";
    BEADS_DOLT_SERVER_USER = "root";
    DOLT_CLI_USER = "root";
    DOLT_CLI_PASSWORD = "";
  };
  beadsLaunchctlEnvironmentScript = pkgs.replaceVars ./client-environment.sh {
    inherit doltServerHost;
  };
  linearSyncEnabled = isKyber;
  federationSyncEnabled = clientEnabled;
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
  beadsLinearCompleteScript = pkgs.replaceVars ./beads-linear-complete.sh {
    inherit (pkgs) bash;
    inherit linearSyncScript;
  };
  federationSyncScript = pkgs.replaceVars ./federation-sync.sh {
    bd = "${homeDir}/.local/bin/bd";
    inherit (pkgs) coreutils;
  };
in
lib.mkIf clientEnabled {
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.dolt.version doltMinVersion;
      message = "pkgs.dolt is ${pkgs.dolt.version}; needs >= ${doltMinVersion} for git+https push (beads_global GitHub backup). Update the dedicated nixpkgs-dolt pin.";
    }
  ];

  home.sessionVariables = beadsClientEnvironment // {
    LINEAR_TEAM_ID = linearTeamId;
  };

  # GUI applications do not source shell session variables. Seed launchd's
  # per-user environment so newly launched agent daemons use Kyber directly.
  launchd.agents.beads-dolt-client-environment = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${beadsLaunchctlEnvironmentScript}"
      ];
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };

  home.file.".local/bin/beads-linear-complete" = lib.mkIf linearSyncEnabled {
    source = beadsLinearCompleteScript;
    executable = true;
  };

  launchd.agents.dolt = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && serverEnabled) {
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
  launchd.agents.dolt-backup-main = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && publisherEnabled) {
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

  launchd.agents.dolt-linear-sync =
    lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && linearSyncEnabled)
      {
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
            BEADS_DOLT_AUTO_START = "0";
            BEADS_DOLT_SERVER_MODE = "1";
            BEADS_DOLT_SERVER_HOST = doltServerHost;
            BEADS_DOLT_SERVER_PORT = "3307";
            BEADS_DOLT_SERVER_USER = "root";
            DOLT_CLI_USER = "root";
            DOLT_CLI_PASSWORD = "";
            LINEAR_TEAM_ID = linearTeamId;
          };
          StandardOutPath = "/tmp/dolt-linear-sync.log";
          StandardErrorPath = "/tmp/dolt-linear-sync.error.log";
        };
      };

  launchd.agents.dolt-federation-sync =
    lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && federationSyncEnabled)
      {
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
            BEADS_DOLT_AUTO_START = "0";
            BEADS_DOLT_SERVER_MODE = "1";
            BEADS_DOLT_SERVER_HOST = doltServerHost;
            BEADS_DOLT_SERVER_PORT = "3307";
            BEADS_DOLT_SERVER_USER = "root";
            DOLT_CLI_USER = "root";
            DOLT_CLI_PASSWORD = "";
          };
          StandardOutPath = "/tmp/dolt-federation-sync.log";
          StandardErrorPath = "/tmp/dolt-federation-sync.error.log";
        };
      };

  systemd.user.services.dolt = lib.mkIf (pkgs.stdenv.isLinux && serverEnabled) {
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
      # Kyber's WAN firewall drops all new public-interface ingress. Binding
      # all addresses makes the SQL service reachable on tailscale0 while
      # retaining the public-ingress deny boundary.
      Environment = [
        "BEADS_DOLT_LISTEN_HOST=0.0.0.0"
        "DOLT_CLI_USER=root"
        "DOLT_CLI_PASSWORD="
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Persist the same client selection in the user manager so Herdr, OpenClaw,
  # and other systemd-launched agents do not inherit a stale shared-server mode.
  systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.isLinux beadsClientEnvironment;

  systemd.user.services.dolt-backup-main = lib.mkIf (pkgs.stdenv.isLinux && publisherEnabled) {
    Unit = {
      Description = "Push beads_global JSONL snapshot to GitHub main";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupScript}";
      WorkingDirectory = repoDir;
    };
  };

  systemd.user.paths.dolt-backup-main = lib.mkIf (pkgs.stdenv.isLinux && publisherEnabled) {
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
        "BEADS_DOLT_AUTO_START=0"
        "BEADS_DOLT_SERVER_MODE=1"
        "BEADS_DOLT_SERVER_HOST=${doltServerHost}"
        "BEADS_DOLT_SERVER_PORT=3307"
        "BEADS_DOLT_SERVER_USER=root"
        "DOLT_CLI_USER=root"
        "DOLT_CLI_PASSWORD="
        "LINEAR_TEAM_ID=${linearTeamId}"
      ];
    };
  };

  systemd.user.timers.dolt-linear-sync = lib.mkIf (pkgs.stdenv.isLinux && linearSyncEnabled) {
    Unit.Description = "Periodically synchronize Beads with Linear";
    Timer = {
      OnBootSec = "4min";
      OnCalendar = "*-*-* *:02/15:00";
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
            "BEADS_DOLT_AUTO_START=0"
            "BEADS_DOLT_SERVER_MODE=1"
            "BEADS_DOLT_SERVER_HOST=${doltServerHost}"
            "BEADS_DOLT_SERVER_PORT=3307"
            "BEADS_DOLT_SERVER_USER=root"
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
      Persistent = true;
      Unit = "dolt-federation-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
