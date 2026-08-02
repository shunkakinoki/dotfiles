{
  config,
  lib,
  pkgs,
  ...
}:
let
  settings = pkgs.replaceVars ./settings.json {
    moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
  };
in
{
  # Use activation script to copy settings.json instead of symlinking
  # This allows ruler and other tools to modify the file
  home.activation.geminiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${settings}"
  '';
}
