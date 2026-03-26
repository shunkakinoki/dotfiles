{
  config,
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.conky ];

  xdg.configFile."conky/conky.conf" = {
    source = ./conky.conf;
    force = true;
  };
}
