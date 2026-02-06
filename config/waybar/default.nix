{ config, ... }:
{
  xdg.configFile."waybar/config.jsonc" = {
    source = ./config.jsonc;
    force = true;
  };
  xdg.configFile."waybar/style.css" = {
    source = ./style.css;
    force = true;
  };
}
