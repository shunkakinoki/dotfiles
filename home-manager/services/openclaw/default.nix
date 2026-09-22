{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;
  k3sProxy = pkgs.writeShellApplication {
    name = "openclaw-k3s-proxy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.iproute2
      pkgs.socat
    ];
    text = builtins.readFile ./k3s-proxy.sh;
  };
  stateMaintenance = pkgs.writeShellApplication {
    name = "openclaw-state-maintenance";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = builtins.readFile ./state-maintenance.sh;
  };
in
# Only enable on kyber (gateway host)
lib.mkIf host.isKyber {
  # Ensure OpenClaw directories exist with correct permissions
  home.activation.openclawSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${homeDir}"
  '';

  # Systemd service for OpenClaw gateway
  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw gateway";
      After = [
        "network-online.target"
        "install-npm-globals.service"
      ];
      Wants = [ "network-online.target" ];
      X-SwitchMethod = "restart";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 10;
    };
    Service = {
      Type = "simple";
      ExecStart = "${homeDir}/.bun/bin/openclaw gateway run --port 18789 --bind loopback";
      Restart = "always";
      RestartSec = "5s";
      # OpenClaw creates read-only SQLite snapshots for concurrent requests.
      # Bound that work so the gateway cannot starve K3s on Kyber's root disk.
      IOAccounting = true;
      IOReadBandwidthMax = "/ 20M";
      IOWriteBandwidthMax = "/ 10M";
      IOReadIOPSMax = "/ 100";
      IOWriteIOPSMax = "/ 50";
      EnvironmentFile = [ "-${homeDir}/dotfiles/.env" ];
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/share/pnpm:${homeDir}/.local/share/fnm/current/bin:${homeDir}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      WorkingDirectory = "${homeDir}/.openclaw";
      StandardOutput = "append:/tmp/openclaw/openclaw-gateway.log";
      StandardError = "append:/tmp/openclaw/openclaw-gateway.log";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Keep the gateway loopback-only while making it reachable from k3s. The
  # proxy binds exclusively to Kyber's CNI bridge, so port 18789 is not exposed
  # on the public or Tailscale interfaces.
  systemd.user.services.openclaw-k3s-proxy = {
    Unit = {
      Description = "OpenClaw k3s bridge proxy";
      After = [ "openclaw-gateway.service" ];
      Requires = [ "openclaw-gateway.service" ];
      X-SwitchMethod = "restart";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
    Service = {
      Type = "simple";
      ExecStart = "${k3sProxy}/bin/openclaw-k3s-proxy";
      Restart = "on-failure";
      RestartSec = "30s";
      NoNewPrivileges = true;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.openclaw-state-maintenance = {
    Unit = {
      Description = "Prune and compact the OpenClaw shared state database";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${stateMaintenance}/bin/openclaw-state-maintenance";
      TimeoutStartSec = "30m";
      IOAccounting = true;
      IOReadBandwidthMax = "/ 20M";
      IOWriteBandwidthMax = "/ 10M";
      IOReadIOPSMax = "/ 100";
      IOWriteIOPSMax = "/ 50";
      EnvironmentFile = [ "-${homeDir}/dotfiles/.env" ];
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
        # Without these the unit's own `systemctl --user` calls cannot reach the
        # session bus, so stopping the gateway silently fails and every
        # state-owning step is refused.
        "XDG_RUNTIME_DIR=%t"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
      ];
      WorkingDirectory = "${homeDir}/.openclaw";
      StandardOutput = "append:/tmp/openclaw/openclaw-state-maintenance.log";
      StandardError = "append:/tmp/openclaw/openclaw-state-maintenance.log";
    };
  };

  systemd.user.timers.openclaw-state-maintenance = {
    Unit.Description = "Periodically bound the OpenClaw shared state database";
    Timer = {
      OnCalendar = "*-*-* 09:20:00 UTC";
      Persistent = true;
      RandomizedDelaySec = "5m";
      Unit = "openclaw-state-maintenance.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.openclaw-snapshot-cache-cleanup = {
    Unit = {
      Description = "Reclaim abandoned OpenClaw SQLite snapshots";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./snapshot-cache-cleanup.py}";
      TimeoutStartSec = "2m";
      Nice = 19;
      IOSchedulingClass = "idle";
      IOAccounting = true;
      IOReadBandwidthMax = "/ 2M";
      IOWriteBandwidthMax = "/ 2M";
      IOReadIOPSMax = "/ 10";
      IOWriteIOPSMax = "/ 10";
      Environment = [ "HOME=${homeDir}" ];
    };
  };

  systemd.user.timers.openclaw-snapshot-cache-cleanup = {
    Unit.Description = "Pace OpenClaw snapshot cache cleanup";
    Timer = {
      OnStartupSec = "10min";
      OnUnitInactiveSec = "5min";
      RandomizedDelaySec = "30s";
      Unit = "openclaw-snapshot-cache-cleanup.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
