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
    stat = "${pkgs.coreutils}/bin/stat";
  };
in
{
  home.activation.secureDotenv = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${script}" "${homeDir}"
  '';
}
