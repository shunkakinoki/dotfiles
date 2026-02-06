{ config, ... }:
{
  xdg.configFile."hypr/hyprland.conf" = {
    source = ./hyprland.conf;
    force = true;
  };
}
