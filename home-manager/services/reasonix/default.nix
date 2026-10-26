{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  # The worker is useful on the Linux matic test host and the macOS galactica
  # host; both carry the Reasonix state directory and CLI on PATH.
  enabled = inputs.host.isGalactica || inputs.host.isMatic;
  stateDir = "${homeDir}/.local/state/reasonix";
  # The base commit installs reasonix as a bun global, which lands in ~/.bun/bin
  # rather than the Nix store, so resolve it from PATH at start time.
  servicePath =
    lib.makeBinPath [
      pkgs.bash
      pkgs.coreutils
    ]
    + ":${homeDir}/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin";
in
{
  # The durable engine: one long-lived `reasonix serve` that keeps every session
  # ("thread") resident, so a turn started hours ago can still be opened and
  # steered. Supervised so it survives crashes and logout.
  launchd.agents.reasonix-server = lib.mkIf (enabled && pkgs.stdenv.hostPlatform.isDarwin) {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${./start.sh}"
        "reasonix"
        stateDir
      ];
      WorkingDirectory = homeDir;
      # Durable: start at login and restart whenever the engine exits.
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = servicePath;
      };
      StandardOutPath = "${stateDir}/server.log";
      StandardErrorPath = "${stateDir}/server.error.log";
    };
  };

  systemd.user.services.reasonix-server = lib.mkIf (enabled && pkgs.stdenv.hostPlatform.isLinux) {
    Unit.Description = "Reasonix durable serve worker";
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash ${./start.sh} reasonix ${stateDir}";
      Restart = "always";
      RestartSec = 10;
      # Keep an idle resident worker cheap and bound runaway tool subprocesses.
      CPUQuota = "200%";
      MemoryMax = "2G";
      TasksMax = 128;
      Environment = "PATH=${servicePath}";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
