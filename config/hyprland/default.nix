{
  pkgs,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    configType = "hyprlang";
    systemd.enable = false;
    extraConfig = ''
      exec-once = noctalia
      exec-once = ${pkgs.hyprshell}/bin/hyprshell run &
      exec-once = ${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent
      exec-once = sleep 3 && ${pkgs.eww}/bin/eww open clock-widget
    ''
    + builtins.readFile ./hyprland.conf;
  };

  # Shells expose native addon dependencies through LD_LIBRARY_PATH. UWSM
  # sources the login profile before starting Hyprland, so keep that broad
  # loader override out of the graphical session and let Nix RUNPATHs select
  # the matching C++ runtime for the compositor closure.
  xdg.configFile."uwsm/env".text = ''
    unset LD_LIBRARY_PATH
  '';

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
