{ config, pkgs, ... }:
{
  programs.walker = {
    enable = true;
    runAsService = true;
  };

  xdg.configFile."walker/config.toml" = {
    source = ./config.toml;
    force = true;
  };
  xdg.configFile."walker/themes/dracula/style.css" = {
    source = ./style.css;
    force = true;
  };
}
