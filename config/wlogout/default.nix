{ config, ... }:
{
  xdg.configFile."wlogout/layout" = {
    source = ./layout;
    force = true;
  };
  xdg.configFile."wlogout/style.css" = {
    source = ./style.css;
    force = true;
  };
}
