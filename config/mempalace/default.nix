{ config, ... }:
let
  homeDir = config.home.homeDirectory;
  configText = builtins.replaceStrings [ "__HOME_DIR__" ] [ homeDir ] (
    builtins.readFile ./config.json
  );
in
{
  home.file.".mempalace/config.json" = {
    text = configText;
    force = true;
  };
}
