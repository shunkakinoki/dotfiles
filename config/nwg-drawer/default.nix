{ pkgs, ... }:
{
  xdg.configFile."nwg-drawer/drawer.css" = {
    source = ./drawer.css;
    force = true;
  };
}
