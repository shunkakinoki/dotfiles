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

  backupCheckScript = pkgs.replaceVars ./scripts/backup-check.sh {
    common = commonScript;
  };

  startScript = pkgs.replaceVars ./scripts/start.sh {
    sed = "${pkgs.gnused}/bin/sed";
    awk = "${pkgs.gawk}/bin/awk";
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

  kaminoMapping = ../../../kamino-tunnels.json;

  # kamino-tunnel.sh listens for kamino<N> on 1080+N and ignores entries whose
  # port disagrees, so reject those at evaluation time instead.
  kaminoIndices = lib.unique (
    map (
      entry:
      let
        match = builtins.match "kamino([1-9][0-9]*)" entry.host;
        index = lib.toInt (builtins.head match);
      in
      if match == null then
        throw "kamino-tunnels.json: host must be kamino<N>, got ${entry.host}"
      else if entry.port != 1080 + index then
        throw "kamino-tunnels.json: ${entry.host} must use port ${toString (1080 + index)}"
      else
        index
    ) (lib.importJSON kaminoMapping)
  );

  # Every host reads quota from kyber, the only host with OAuth auth files, over
  # the tailnet with the CLIProxyAPI management password. The public hostname
  # routes /v0/management to CPA Manager Plus, which takes a different key.
  quotaScript = pkgs.replaceVars ./scripts/quota.sh {
    jq = "${pkgs.jq}/bin/jq";
    curl = "${pkgs.curl}/bin/curl";
    mapping = "${kaminoMapping}";
    management_url =
      if objectstoreEnabled then
        "http://127.0.0.1:8317/v0/management"
      else
        "http://kyber.tail950b36.ts.net:8317/v0/management";
  };

  quotaCli = pkgs.writeShellScriptBin "cliproxy-quota" (builtins.readFile quotaScript);

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
        X-Restart-Triggers = [ "${kaminoMapping}" ];
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

  home.packages = [ quotaCli ] ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin cliWrapper;

  # Main service
  launchd.agents.cliproxyapi = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${startScript}"
      ];
      EnvironmentVariables = {
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
      # Config and auth changes hot-reload in the running server. Changes to
      # the start script or image apply on the next explicit restart.
      X-SwitchMethod = "reload";
      X-Reload-Triggers = [
        "${config.home.file.".cli-proxy-api/config.template.yaml".source}"
      ]
      ++ lib.optional objectstoreEnabled "${kaminoMapping}";
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
      ExecReload = "${pkgs.bash}/bin/bash ${startScript} render";
      # Give the start wrapper's TERM trap time to flush usage + docker stop
      # the container cleanly before systemd escalates to SIGKILL.
      TimeoutStopSec = 45;
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # The rendered config is derived from ~/dotfiles/.env and the host-local
  # removed-models list, so re-render and hot-reload whenever either changes.
  # Otherwise a rotated or newly added key keeps its stale value until the next
  # home-manager switch or manual reload.
  systemd.user.paths.cliproxyapi-env-reload = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Watch CLIProxyAPI render inputs (.env, removed-models)";
    Path = {
      PathChanged = [
        "%h/dotfiles/.env"
        "%h/.config/cliproxyapi/removed-models"
      ];
      Unit = "cliproxyapi-env-reload.service";
    };
    Install.WantedBy = [ "paths.target" ];
  };

  # try-reload-or-restart only acts on a running unit, and cliproxyapi defines
  # ExecReload, so this re-renders config.yaml and the server hot-reloads it
  # without dropping in-flight requests.
  systemd.user.services.cliproxyapi-env-reload = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Re-render and hot-reload CLIProxyAPI after a render input changes";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user try-reload-or-restart cliproxyapi.service";
    };
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
  # Token refreshes arrive in bursts, and the default start limit then stops
  # both this service and its path unit until someone resets them, which
  # silently leaves S3 behind.
  systemd.user.services.cliproxyapi-backup-auth = lib.mkIf objectstoreEnabled {
    Unit.Description = "CLIProxyAPI auth backup";
    Unit.X-SwitchMethod = "keep-old";
    Unit.StartLimitIntervalSec = 0;
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupScript} auth";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.awscli2
          pkgs.coreutils
          pkgs.docker
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
      # The analytics snapshot now stops cpa-manager-plus, folds the WAL back
      # and copies the database file, so it is a short burst instead of a
      # throttled 90-minute read. Throttling it to 5 MB/s made the hourly run
      # outlive its own interval, which pinned the WAL permanently and left an
      # 84 GB -wal on kyber's root disk (2026-10-19). Keep a low IO weight and
      # let the copy finish quickly.
      IOAccounting = true;
      IOWeight = 10;
      # A hung snapshot holds the unit in "activating", which stops the hourly
      # timer without ever failing, so the drift check cannot see it.
      TimeoutStartSec = "2h";
      ExecStart = "${pkgs.bash}/bin/bash ${backupScript} full";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.awscli2
          pkgs.coreutils
          pkgs.gnutar
          pkgs.gzip
          pkgs.sqlite
          pkgs.docker
        ]
      }:/usr/bin:/usr/sbin";
      UMask = "0077";
    };
  };

  systemd.user.timers.cliproxyapi-backup = lib.mkIf objectstoreEnabled {
    Unit.Description = "Daily CLIProxyAPI and CPA Manager Plus backup";
    Timer = {
      OnBootSec = "5min";
      # Daily, not hourly: the analytics snapshot copies a ~29 GB database and
      # pauses the manager while it does, so it belongs in a quiet window
      # rather than 24 times a day.
      OnCalendar = "*-*-* 04:00:00 UTC";
      Persistent = true;
      Unit = "cliproxyapi-backup.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # The path unit can miss events, so push the auth cache on a clock as well.
  systemd.user.timers.cliproxyapi-backup-auth = lib.mkIf objectstoreEnabled {
    Unit.Description = "Periodically back up CLIProxyAPI auth files";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
      Unit = "cliproxyapi-backup-auth.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # systemctl comes from the host: a newer Nix client cannot reach kyber's
  # older user manager, and its failed queries read as "unit not failed".
  systemd.user.services.cliproxyapi-backup-check = lib.mkIf objectstoreEnabled {
    Unit.Description = "Alert when the CLIProxyAPI S3 auth backup is stale";
    Unit.X-SwitchMethod = "keep-old";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${backupCheckScript}";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.awscli2
          pkgs.coreutils
          pkgs.findutils
          pkgs.curl
        ]
      }:/usr/bin";
      UMask = "0077";
    };
  };

  systemd.user.timers.cliproxyapi-backup-check = lib.mkIf objectstoreEnabled {
    Unit.Description = "Hourly CLIProxyAPI S3 auth backup drift check";
    Timer = {
      OnBootSec = "20min";
      OnCalendar = "*:30";
      Persistent = true;
      Unit = "cliproxyapi-backup-check.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # The tunnels only run on kyber, so other hosts must not route keys to them.
  xdg.configFile."cliproxyapi/kamino-tunnels.json" = lib.mkIf objectstoreEnabled {
    source = kaminoMapping;
  };

  # One SOCKS tunnel per kamino node named in kamino-tunnels.json. Nix rejects
  # a literal systemd.user.services next to the generated set, hence the import.
  imports = [
    {
      systemd.user.services = lib.listToAttrs (
        map (index: lib.nameValuePair "kamino-tunnel-${toString index}" (kaminoTunnel index)) kaminoIndices
      );
    }
  ];
}
