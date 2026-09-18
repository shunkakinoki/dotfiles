{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;

  # OAuth refresh tokens rotate on every refresh, so a copy refreshed on one
  # host invalidates the copies on every other host. Only kyber holds the OAuth
  # auth files and the S3 store they are backed up to.
  objectstoreEnabled = pkgs.stdenv.hostPlatform.isLinux && host.isKyber;

  commonScript = pkgs.replaceVars ./scripts/common.sh {
    aws = "${pkgs.awscli2}/bin/aws";
    sqlite3 = "${pkgs.sqlite}/bin/sqlite3";
    tar = "${pkgs.gnutar}/bin/tar";
    objectstore_enabled = lib.boolToString objectstoreEnabled;
  };

  hydrateScript = pkgs.replaceVars ./scripts/hydrate.sh {
    common = commonScript;
  };

  backupScript = pkgs.replaceVars ./scripts/backup.sh {
    common = commonScript;
  };

  startScript = pkgs.replaceVars ./scripts/start.sh {
    sed = "${pkgs.gnused}/bin/sed";
    aws = "${pkgs.awscli2}/bin/aws";
    jq = "${pkgs.jq}/bin/jq";
    flock = "${pkgs.flock}/bin/flock";
    common = commonScript;
  };

  # Smart wrapper that handles both NixOS and non-NixOS Linux
  # On NixOS: docker group is properly inherited, or use /run/wrappers/bin/sg
  # On non-NixOS: systemd user session may lack docker group, use /usr/bin/sg
  dockerStartScript = pkgs.writeShellScript "cliproxyapi-docker-start" (
    builtins.readFile (
      pkgs.replaceVars ./scripts/docker-start.sh {
        inherit (pkgs) bash;
        start_script = startScript;
        inherit (pkgs) docker;
      }
    )
  );

  wrapperScript = pkgs.replaceVars ./scripts/wrapper.sh {
    common = commonScript;
  };

  cliWrapper = pkgs.writeShellScriptBin "cliproxyapi" (builtins.readFile wrapperScript);

  kaminoTunnelScript = pkgs.replaceVars ./scripts/kamino-tunnel.sh {
    jq = "${pkgs.jq}/bin/jq";
    flock = "${pkgs.flock}/bin/flock";
    ssh = "${pkgs.openssh}/bin/ssh";
  };

  kaminoTunnel =
    index:
    lib.mkIf objectstoreEnabled {
      Unit = {
        Description = "Kamino SOCKS tunnel ${toString index}";
        After = [ "network-online.target" ];
        X-SwitchMethod = "restart";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash ${kaminoTunnelScript} ${toString index}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };
in
{
  # Hydrate auth cache after home-manager switch
  home.activation.hydrateCliproxyAuths = lib.mkIf objectstoreEnabled (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.bash}/bin/bash ${hydrateScript} || true
    ''
  );

  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [ cliWrapper ];

  # Main service
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${startScript}"
      ];
      Environment = {
        PATH = "${
          lib.makeBinPath [
            pkgs.gnused
            pkgs.coreutils
            pkgs.awscli2
          ]
        }:/opt/homebrew/bin:/usr/local/bin:/usr/bin";
      };
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cliproxyapi.log";
      StandardErrorPath = "/tmp/cliproxyapi.error.log";
    };
  };

  # Linux systemd
  systemd.user.services.cliproxyapi = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "CLI Proxy API server";
      After = [
        "network.target"
        "docker.service"
      ];
      Wants = [ "docker.service" ];
      X-Restart-Triggers = [
        "${config.home.file.".cli-proxy-api/config.template.yaml".source}"
      ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.gnused
          pkgs.bash
          pkgs.coreutils
          pkgs.awscli2
          pkgs.docker
          pkgs.curl
          pkgs.gnugrep
          pkgs.shadow
        ]
      }:/usr/bin:/usr/sbin";
      ExecStart = "${dockerStartScript}";
      # Give the start wrapper's TERM trap time to flush usage + docker stop
      # the container cleanly before systemd escalates to SIGKILL.
      TimeoutStopSec = 45;
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.paths.cliproxyapi-backup-auth = lib.mkIf objectstoreEnabled {
    Unit.Description = "Watch auth directories for changes";
    Path = {
      PathChanged = [
        "%h/.cli-proxy-api/objectstore/auths"
      ];
      Unit = "cliproxyapi-backup-auth.service";
    };
    Install.WantedBy = [ "paths.target" ];
  };

  # CLIProxyAPI rewrites auth files on every token refresh, so the path unit
  # fires many times an hour. It gets the auth-only entrypoint and a PATH
  # without sqlite/tar so the analytics snapshot cannot ride along.
  systemd.user.services.cliproxyapi-backup-auth = lib.mkIf objectstoreEnabled {
    Unit.Description = "CLIProxyAPI auth backup";
    Unit.X-SwitchMethod = "keep-old";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupScript} auth";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.awscli2
          pkgs.coreutils
        ]
      }";
      UMask = "0077";
    };
  };

  systemd.user.services.cliproxyapi-backup = lib.mkIf objectstoreEnabled {
    Unit.Description = "CLIProxyAPI auth and CPA Manager Plus analytics backup";
    Unit.X-SwitchMethod = "keep-old";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupScript} full";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.awscli2
          pkgs.coreutils
          pkgs.gnutar
          pkgs.gzip
          pkgs.sqlite
        ]
      }";
      UMask = "0077";
    };
  };

  systemd.user.timers.cliproxyapi-backup = lib.mkIf objectstoreEnabled {
    Unit.Description = "Periodically back up CLIProxyAPI and CPA Manager Plus data";
    Timer = {
      OnBootSec = "5min";
      OnCalendar = "hourly";
      Persistent = true;
      Unit = "cliproxyapi-backup.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # One SOCKS tunnel per kamino node. Each exits cleanly unless the machine-local
  # ~/.config/cliproxyapi/kamino-tunnels.json maps a credential to it.
  systemd.user.services.kamino-tunnel-1 = kaminoTunnel 1;
  systemd.user.services.kamino-tunnel-2 = kaminoTunnel 2;
  systemd.user.services.kamino-tunnel-3 = kaminoTunnel 3;
}
