{
  config,
  lib,
  pkgs,
  ...
}:
let
  geminiSettingsSource = ./settings.json;
in
{
  # Use activation script to copy settings.json instead of symlinking
  # This allows ruler and other tools to modify the file
  home.activation.geminiSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.gemini"
    if [ ! -f "$HOME/.gemini/settings.json" ]; then
      $DRY_RUN_CMD cp ${geminiSettingsSource} "$HOME/.gemini/settings.json"
      $DRY_RUN_CMD chmod 644 "$HOME/.gemini/settings.json"
    fi
  '';
}
