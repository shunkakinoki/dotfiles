{ pkgs, ... }:
let
  inherit (pkgs) lib;
  configFile = pkgs.writeText "ghostty-config" (
    builtins.replaceStrings
      [ "@FISH@" ]
      [ "${pkgs.fish}/bin/fish" ]
      (builtins.readFile ./config)
  );
in
{
  xdg.configFile."ghostty/config" = {
    source = configFile;
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
        source = configFile;
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
