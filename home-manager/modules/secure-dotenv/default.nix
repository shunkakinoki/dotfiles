{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  script = pkgs.replaceVars ./secure-dotenv.sh {
    find = "${pkgs.findutils}/bin/find";
    nice = "${pkgs.coreutils}/bin/nice";
    stat = "${pkgs.coreutils}/bin/stat";
    timeout = "${pkgs.coreutils}/bin/timeout";
  };
in
{
  home.activation.secureDotenv = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${script}" "${homeDir}"
  '';
}
