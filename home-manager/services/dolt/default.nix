{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isKyber isKamino;
  homeDir = config.home.homeDirectory;
  repoDir = "${homeDir}/dotfiles";
  beadsDir = "${homeDir}/.beads/shared-server/dolt";
  linearWorkspace = "shunkakinoki";
  linearTeamId = "679ab4ed-3df3-458d-8574-4962f3ebbf31";
  linearSyncPath = "${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
  # One live store owns reads, writes, and leases. Spokes never create a local
  # server or merge another writable copy into the authority.
  doltServerHost = if isKyber then "127.0.0.1" else "kyber.tail950b36.ts.net";
  beadsClientEnvironment = {
    BEADS_DOLT_AUTO_START = "0";
    BEADS_DOLT_SERVER_MODE = "1";
    BEADS_DOLT_SERVER_HOST = doltServerHost;
    BEADS_DOLT_SERVER_PORT = "3307";
    BEADS_DOLT_SERVER_USER = "root";
    BEADS_NODE_ID = "kyber";
    DOLT_CLI_USER = "root";
    DOLT_CLI_PASSWORD = "";
  }
  // lib.optionalAttrs isKyber {
    BEADS_DOLT_DATA_DIR = beadsDir;
  };
  beadsLaunchctlEnvironmentScript = pkgs.replaceVars ./client-environment.sh {
    inherit doltServerHost;
  };
  linearSyncEnabled = isKyber;
  doltMinVersion = "2.2.2";
  startScript = pkgs.replaceVars ./start.sh {
    inherit beadsDir;
    inherit (pkgs) dolt;
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

in
{
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.dolt.version doltMinVersion;
      message = "pkgs.dolt is ${pkgs.dolt.version}; needs >= ${doltMinVersion} for the managed Beads SQL server. Update the dedicated nixpkgs-dolt pin.";
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

  systemd.user.services.dolt = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && isKyber) {
    Unit = {
      Description = "Authoritative Beads SQL server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${startScript}";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = repoDir;
      # Kyber's WAN firewall drops all new public-interface ingress. Binding
      # all addresses makes the SQL service reachable on
      # tailscale0 while retaining the public-ingress deny boundary.
      Environment = [
        "BEADS_DOLT_LISTEN_HOST=0.0.0.0"
        "DOLT_CLI_USER=root"
        "DOLT_CLI_PASSWORD="
      ];
    }
    // lib.optionalAttrs isKyber {
      # DOLT_BACKUP performs the off-site snapshot inside the server process.
      # Bound that bulk writer so it cannot starve Kine and PostgreSQL on the
      # shared root disk; normal transactional writes remain far below 20 MB/s.
      IOAccounting = true;
      IOWriteBandwidthMax = "/ 20M";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Persist the same client selection in the user manager so Herdr, OpenClaw,
  # and other systemd-launched agents do not inherit a stale shared-server mode.
  systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux beadsClientEnvironment;

  # Herdr launches workers without a login shell. Give its child processes the
  # managed server policy directly so they cannot start a competing Dolt server.
  systemd.user.services.herdr-server = lib.mkIf isKamino {
    Service.Environment = lib.mapAttrsToList (name: value: "${name}=${value}") beadsClientEnvironment;
  };

  systemd.user.services.dolt-linear-sync =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && linearSyncEnabled)
      {
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
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") (
            beadsClientEnvironment
            // {
              HOME = homeDir;
              PATH = linearSyncPath;
              LINEAR_TEAM_ID = linearTeamId;
            }
          );
        };
      };

  systemd.user.timers.dolt-linear-sync =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && linearSyncEnabled)
      {
        Unit.Description = "Periodically synchronize Beads with Linear";
        Timer = {
          OnBootSec = "4min";
          OnCalendar = "*-*-* *:02/15:00";
          Persistent = true;
          Unit = "dolt-linear-sync.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };

}
