{ config, ... }:
{
  xdg.configFile."wofi/config" = {
    source = ./config;
    force = true;
  };
  xdg.configFile."wofi/style.css" = {
    source = ./style.css;
    force = true;
  };
}
