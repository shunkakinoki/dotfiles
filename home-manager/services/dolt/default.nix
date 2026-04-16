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
  enabled = isKyber || isGalactica;
  startScript = pkgs.writeShellScript "dotfiles-dolt-start.sh" ''
    set -euo pipefail

    mkdir -p "${beadsDir}"

    if [ -d "${beadsDir}/dolt" ] && [ ! -L "${beadsDir}/dolt" ]; then
      if [ -e "${beadsDir}/df" ]; then
        echo "Refusing to migrate ${beadsDir}/dolt because ${beadsDir}/df already exists" >&2
        exit 1
      fi

      mv -f "${beadsDir}/dolt" "${beadsDir}/df"
    fi

    if [ -d "${beadsDir}/df" ]; then
      ln -sfn df "${beadsDir}/dolt"
    fi

    exec "${pkgs.dolt}/bin/dolt" sql-server \
      -H 127.0.0.1 \
      -P 3307 \
      --data-dir "${beadsDir}" \
      --loglevel info
  '';
in
lib.mkIf enabled {
  launchd.agents.dolt = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ startScript ];
      KeepAlive = true;
      RunAtLoad = true;
      WorkingDirectory = repoDir;
      StandardOutPath = "/tmp/dolt.log";
      StandardErrorPath = "/tmp/dolt.error.log";
    };
  };

  systemd.user.services.dolt = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Dolt SQL server for dotfiles beads";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = startScript;
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = repoDir;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
