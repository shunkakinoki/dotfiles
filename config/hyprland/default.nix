{
  config,
  inputs,
  pkgs,
  ...
}:
let
  hyprexpoPlugin = inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    systemd.enable = false;
    extraConfig = ''
      plugin = ${hyprexpoPlugin}/lib/libhyprexpo.so
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
}
