{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  exportGuiEnv = pkgs.replaceVars ./export-gui-env.sh {
    launchctl = "/bin/launchctl";
    printer = "${./print-env-file.sh}";
  };
in
{
  home.file.".config/shell/print-env-file.sh" = {
    source = ./print-env-file.sh;
    executable = true;
  };

  home.file.".config/shell/load-env-file.sh".source = ./load-env-file.sh;

  # Activation runs under `launchctl asuser ... sudo`, whose `launchctl setenv`
  # never reaches the GUI domain and would not survive a reboot anyway. A
  # RunAtLoad agent runs inside the GUI session at every login, and WatchPaths
  # re-exports whenever the .env file changes.
  launchd.agents.dotenv-gui-environment = lib.mkIf isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${exportGuiEnv}"
      ];
      RunAtLoad = true;
      WatchPaths = [ "${config.home.homeDirectory}/dotfiles/.env" ];
      ProcessType = "Background";
    };
  };
}
