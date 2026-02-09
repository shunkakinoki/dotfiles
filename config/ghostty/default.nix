{ config, pkgs, ... }:
let
  fishPath = "${pkgs.fish}/bin/fish";
  staticConfig = builtins.readFile ./config;
  configText = builtins.replaceStrings [ "__FISH_PATH__" ] [ fishPath ] staticConfig;
in
{
  xdg.configFile."ghostty/config" = {
    text = configText;
  };
}
