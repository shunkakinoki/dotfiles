{
  pkgs,
  lib,
  ...
}:
{
  gtk = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    theme = {
      name = "Adwaita";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      size = 24;
    };
    gtk4.theme = {
      name = "Adwaita";
      package = pkgs.gnome-themes-extra;
    };
  };
}
