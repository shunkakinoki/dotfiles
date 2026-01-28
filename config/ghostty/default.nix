{ config, ... }:
{
  xdg.configFile."ghostty/config" = {
    source = ./config;
  };
}
