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
  wikiDir = "${homeDir}/ghq/github.com/shunkakinoki/wiki";
  qmdBin = "${homeDir}/.bun/bin/qmd";
  enabled = isKyber || isGalactica;
in
lib.mkIf enabled {
  home.activation.qmdSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.nodejs}/bin:${homeDir}/.bun/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${qmdBin}" "${wikiDir}"
  '';

  launchd.agents.qmd = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        qmdBin
        "mcp"
        "--http"
      ];
      # qmd's shebang is `env node`; without an explicit PATH it crash-loops at
      # login until another agent's `launchctl setenv PATH` happens to land.
      EnvironmentVariables = {
        PATH = "${pkgs.nodejs}/bin:${homeDir}/.bun/bin:/usr/bin:/bin";
      };
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/qmd.log";
      StandardErrorPath = "/tmp/qmd.error.log";
    };
  };

  systemd.user.services.qmd = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "QMD hybrid search engine";
      After = [
        "network.target"
        "install-npm-globals.service"
      ];
      Wants = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${qmdBin} mcp --http";
      Restart = "always";
      RestartSec = 5;
      Environment = [
        "HOME=${homeDir}"
        "PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/share/pnpm:${homeDir}/.local/share/fnm/current/bin:${homeDir}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
