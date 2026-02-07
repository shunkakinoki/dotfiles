{
  config,
  inputs,
  pkgs,
  ...
}:
let
  hyprexpoPlugin = pkgs.hyprlandPlugins.hyprexpo;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd.enable = false;
    extraConfig = ''
      plugin = ${hyprexpoPlugin}/lib/libhyprexpo.so
      exec-once = ${pkgs.swww}/bin/swww-daemon
    ''
    + builtins.readFile ./hyprland.conf;
  };

  xdg.configFile."hypr/hypridle.conf" = {
    source = ./hypridle.conf;
    force = true;
  };
  xdg.configFile."hypr/hyprlock.conf" = {
    source = ./hyprlock.conf;
    force = true;
  };

  xdg.configFile."hypr/scripts/osd-volume.sh" = {
    source = ./scripts/osd-volume.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."hypr/scripts/osd-brightness.sh" = {
    source = ./scripts/osd-brightness.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."hypr/scripts/toggle-terminal.sh" = {
    source = ./scripts/toggle-terminal.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."hypr/scripts/record-screen.sh" = {
    source = ./scripts/record-screen.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."hypr/scripts/wofi-wifi.sh" = {
    source = ./scripts/wofi-wifi.sh;
    executable = true;
    force = true;
  };
}
