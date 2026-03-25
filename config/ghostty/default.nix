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
  xdg.configFile."ghostty/themes/Dracula Custom" = {
    source = ./themes + "/Dracula Custom";
  };
  xdg.configFile."ghostty/themes/Catppuccin Latte Custom" = {
    source = ./themes + "/Catppuccin Latte Custom";
  };
}
