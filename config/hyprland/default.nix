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
      exec-once = ${pkgs.mpvpaper}/bin/mpvpaper -o "no-audio loop-playlist=inf shuffle hwdec=auto-copy vf=crop=3240:2160" ALL ~/.local/share/wallpapers/aerial-playlist.m3u
      exec-once = ${pkgs.hyprpanel}/bin/hyprpanel
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
}
