{ config, pkgs, inputs, ... }:
let
  inherit (pkgs) lib;
  inherit (inputs.host) isKyber isGalactica;
  homeDir = config.home.homeDirectory;
  wikiDir = "${homeDir}/ghq/github.com/shunkakinoki/wiki";
  qmdBin = "${homeDir}/.bun/bin/qmd";
  enabled = isKyber || isGalactica;
in
lib.mkIf enabled {
  home.activation.qmdSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${qmdBin}" "${wikiDir}"
  '';

  launchd.agents.qmd = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        qmdBin
        "mcp"
        "--http"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/qmd.log";
      StandardErrorPath = "/tmp/qmd.error.log";
    };
  };

  systemd.user.services.qmd = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "QMD hybrid search engine";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${qmdBin} mcp --http";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
