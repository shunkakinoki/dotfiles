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

  home.activation = lib.mkIf isDarwin {
    exportGuiDotenv = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${exportGuiEnv}"
    '';
  };
}
