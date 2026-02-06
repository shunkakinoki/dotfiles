{
  config,
  inputs,
  pkgs,
  ...
}:
let
  hyprexpoPlugin = pkgs.hyprlandPlugins.hyprexpo;
  wallpaper = pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha-alt;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
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
  xdg.configFile."hypr/hyprpaper.conf" = {
    text = ''
      splash = false
      ipc = on
      preload = ${wallpaper}/share/backgrounds/nixos/nix-wallpaper-nineish-catppuccin-mocha-alt.png
      wallpaper = ,${wallpaper}/share/backgrounds/nixos/nix-wallpaper-nineish-catppuccin-mocha-alt.png
    '';
    force = true;
  };
}
