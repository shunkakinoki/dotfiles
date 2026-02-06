{
  config,
  inputs,
  pkgs,
  ...
}:
let
  hyprexpoPlugin = pkgs.hyprlandPlugins.hyprexpo;
  wallpaper = "${pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha-alt}/share/backgrounds/nixos/nix-wallpaper-nineish-catppuccin-mocha-alt.png";
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd.enable = false;
    extraConfig = ''
      plugin = ${hyprexpoPlugin}/lib/libhyprexpo.so
      exec-once = ${pkgs.swaybg}/bin/swaybg -i ${wallpaper} -m fill
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
