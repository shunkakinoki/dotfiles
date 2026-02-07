{ config, pkgs, ... }:
{
  xdg.configFile."walker/config.toml" = {
    source = ./config.toml;
    force = true;
  };
  xdg.configFile."walker/themes/dracula/style.css" = {
    source = ./style.css;
    force = true;
  };
}
