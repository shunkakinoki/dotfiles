{ pkgs, ... }:
let
  inherit (pkgs) lib;
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

  # macOS GUI app reads from ~/Library/Application Support/com.mitchellh.ghostty/
  home.file."Library/Application Support/com.mitchellh.ghostty/config" =
    lib.mkIf pkgs.stdenv.isDarwin
      {
        text = configText;
      };
  home.file."Library/Application Support/com.mitchellh.ghostty/themes/Dracula Custom" =
    lib.mkIf pkgs.stdenv.isDarwin
      {
        source = ./themes + "/Dracula Custom";
      };
  home.file."Library/Application Support/com.mitchellh.ghostty/themes/Catppuccin Latte Custom" =
    lib.mkIf pkgs.stdenv.isDarwin
      {
        source = ./themes + "/Catppuccin Latte Custom";
      };
}
