{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  # Keys handed to GUI apps through launchctl. Every entry becomes readable by
  # every GUI process in the session, so keep the list to what an app needs.
  guiEnvKeys = [
    "AMP_API_KEY"
    "OPENCODE_API_KEY"
  ];
  exportGuiEnv = pkgs.replaceVars ./export-gui-env.sh {
    launchctl = "/bin/launchctl";
    printer = "${./print-env-file.sh}";
    keys = lib.concatStringsSep " " guiEnvKeys;
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
