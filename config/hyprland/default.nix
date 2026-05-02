{
  pkgs,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd.enable = false;
    extraConfig = ''
      exec-once = noctalia-shell
      exec-once = ${pkgs.hyprshell}/bin/hyprshell run &
      exec-once = ${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent
      exec-once = sleep 3 && ${pkgs.eww}/bin/eww open clock-widget
      exec-once = ${pkgs.nwg-dock-hyprland}/bin/nwg-dock-hyprland -d -i 48 -hd 0
    ''
    + builtins.readFile ./hyprland.conf;
  };

  xdg.configFile."hypr/hypridle.conf" = {
    source = ./hypridle.conf;
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
