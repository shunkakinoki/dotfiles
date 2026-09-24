{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  # The worker is only useful on hosts that carry a Reasonix state directory
  # and a CLI on PATH; Galactica is the current proof-of-concept target.
  enabled = inputs.host.isGalactica;
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
      Environment = "PATH=${servicePath}";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
