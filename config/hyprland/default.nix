{ config, ... }:
{
  xdg.configFile."hypr/hyprland.conf" = {
    source = ./hyprland.conf;
    force = true;
  };
  xdg.configFile."hypr/hypridle.conf" = {
    source = ./hypridle.conf;
    force = true;
  };
  xdg.configFile."hypr/hyprlock.conf" = {
    source = ./hyprlock.conf;
    force = true;
  };
}
