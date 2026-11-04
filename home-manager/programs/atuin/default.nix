{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Kamino workers and kyber only upload their own records; pulling every
  # other host's multi-GB thread store onto them wastes disk and sync time.
  uploadOnly = inputs.host.isKamino || inputs.host.isKyber;
  # Threads (agent session capture/resume) shipped in 18.24; older builds
  # silently ignore the [threads] table and stop capturing.
  minVersion = "18.24.0";
  loginSecret = ../../../named-hosts/atuin/login.age;
  hookClient = pkgs.writeShellScriptBin "atuin" (
    lib.replaceStrings
      [ "@atuin@" "@timeout@" ]
      [ "${pkgs.atuin}/bin/atuin" "${pkgs.coreutils}/bin/timeout" ]
      (builtins.readFile ./hook-client.sh)
  );
  boundedAtuin = pkgs.symlinkJoin {
    name = "atuin-${pkgs.atuin.version}";
    paths = [
      hookClient
      pkgs.atuin
    ];
    passthru.version = pkgs.atuin.version;
    meta = pkgs.atuin.meta;
  };
  pruneForeign = pkgs.writeShellApplication {
    name = "atuin-prune-foreign";
    runtimeInputs = with pkgs; [
      atuin
      sqlite
      procps
      gawk
      gnused
      coreutils
    ];
    text = builtins.readFile ./prune-foreign.sh;
  };
in
{
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.atuin.version minVersion;
      message = "atuin ${pkgs.atuin.version} < ${minVersion}: Threads capture needs a newer nixpkgs.";
    }
  ];

  home.activation.atuinLogin = lib.mkIf (builtins.pathExists loginSecret) (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../activation/atuin-login.sh}" \
        "${loginSecret}" \
        "${config.home.homeDirectory}/.ssh/id_ed25519" \
        "${pkgs.rage}/bin/rage" \
        "${pkgs.atuin}/bin/atuin" \
        "${pkgs.coreutils}/bin/timeout" \
        "${pkgs.openssh}/bin/ssh-keygen" \
        "shunkakinoki" \
        "${config.home.homeDirectory}/.local/share/atuin"
    ''
  );

  programs.atuin = {
    enable = true;
    package = boundedAtuin;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    # Threads are captured by the daemon, which also takes over syncing.
    daemon.enable = true;
    settings = {
      auto_sync = !uploadOnly;
      sync_frequency = "3m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
      filter_mode = "global";
      # Applying multi-million-record thread syncs runs queries for 15s+ on a
      # large history.db; the 2s default aborts sync with "pool timed out".
      local_timeout = 120;
      sync = {
        records = true;
      };
      threads = {
        capture = true;
        capture_tools = true;
      };
    };
  };

  systemd.user.services.atuin-push = lib.mkIf uploadOnly {
    Unit = {
      Description = "Push this host's atuin records (one-way)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.atuin}/bin/atuin store push";
    };
  };

  systemd.user.timers.atuin-push = lib.mkIf uploadOnly {
    Unit.Description = "Periodic one-way atuin push";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "3min";
      Persistent = true;
      Unit = "atuin-push.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.atuin-prune-foreign = lib.mkIf uploadOnly {
    Unit.Description = "Drop other hosts' records from the local atuin store";
    Service = {
      Type = "oneshot";
      ExecStart = "${pruneForeign}/bin/atuin-prune-foreign";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.atuin-prune-foreign = lib.mkIf uploadOnly {
    Unit.Description = "Daily atuin foreign-record prune";
    Timer = {
      OnBootSec = "15min";
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
      Unit = "atuin-prune-foreign.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
