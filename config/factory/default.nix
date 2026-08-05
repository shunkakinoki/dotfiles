{
  config,
  lib,
  pkgs,
  ...
}:
let
  factorySettingsActivation = ./activate-settings.sh;
in
{
  home.file.".factory/config.json" = {
    source = ./config.json;
    force = true;
  };

  # Factory owns settings.json and rewrites it as the app evolves. Merge only
  # the managed Droid model and git-ai hooks so unrelated Factory preferences
  # survive.
  home.activation.factorySettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${factorySettingsActivation}" \
      "${./settings.json}" \
      "${pkgs.jq}/bin/jq"
  '';
}
