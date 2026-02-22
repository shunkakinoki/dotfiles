{ pkgs, ... }:
{
  xdg.configFile."hyprshell/config.toml" = {
    source = ./config.toml;
    force = true;
  };
}
