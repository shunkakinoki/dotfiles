{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  services.darkman = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    settings = {
      usegeoclue = true;
    };
    darkModeScripts = {
      gtk-theme = builtins.readFile ./dark-mode.sh;
    };
    lightModeScripts = {
      gtk-theme = builtins.readFile ./light-mode.sh;
    };
  };
}
