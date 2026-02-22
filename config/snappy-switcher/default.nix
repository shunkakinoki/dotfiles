{ ... }:
{
  xdg.configFile."snappy-switcher/config.ini" = {
    source = ./config.ini;
    force = true;
  };
}
