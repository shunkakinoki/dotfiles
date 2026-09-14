{
  config,
  lib,
  pkgs,
  ...
}:
let
  mergeMoshiHooks = import ../shared/merge-moshi-hooks.nix { inherit pkgs; };
  settings =
    mergeMoshiHooks "gemini-settings.json" ./settings.json
      ../../generated/hooks/moshi/gemini/settings.json;
in
{
  # Use activation script to copy settings.json instead of symlinking
  # This allows ruler and other tools to modify the file
  home.activation.geminiSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${settings}"
  '';
}
