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
      gtk-theme = ''
        ${pkgs.dconf}/bin/dconf write \
          /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
        ${pkgs.dconf}/bin/dconf write \
          /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
      '';
    };
    lightModeScripts = {
      gtk-theme = ''
        ${pkgs.dconf}/bin/dconf write \
          /org/gnome/desktop/interface/color-scheme "'prefer-light'"
        ${pkgs.dconf}/bin/dconf write \
          /org/gnome/desktop/interface/gtk-theme "'Adwaita'"
      '';
    };
  };
}
