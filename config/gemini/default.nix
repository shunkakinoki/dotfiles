{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.activation.geminiSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${./settings.json}"
  '';

  home.activation.antigravitySettings =
    config.lib.dag.entryAfter [ "writeBoundary" "hydrateCcsSettings" ]
      ''
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-antigravity.sh}" "${pkgs.jq}/bin/jq"
      '';
}
