{ pkgs, ... }:
let
  inherit (pkgs) lib;
  dconf = "${pkgs.dconf}/bin/dconf";
  readScript = file:
    builtins.replaceStrings [ "@dconf@" ] [ dconf ] (builtins.readFile file);
in
{
  services.darkman = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    settings = {
      usegeoclue = true;
    };
    darkModeScripts = {
      gtk-theme = readScript ./dark-mode.sh;
    };
    lightModeScripts = {
      gtk-theme = readScript ./light-mode.sh;
    };
  };
}
