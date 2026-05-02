{
  inputs,
  pkgs,
  ...
}:
{
  programs.noctalia-shell = {
    enable = true;
    package = inputs.noctalia-shell.packages.${pkgs.system}.default;

    settings = {
      bar = {
        clock.format = "%Y/%m/%d %H:%M:%S";
        battery.showLabel = true;
        network.showLabel = false;
        bluetooth.showLabel = false;
        transparent = true;
        workspaces = {
          showIcons = true;
          showApplicationIcons = true;
          numberedActiveIndicator = "underline";
        };
      };
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 14;
      };
      notifications = {
        position = "top-right";
        cacheActions = true;
        showActionsOnHover = false;
      };
      osd = {
        enable = true;
        orientation = "vertical";
        location = "right";
      };
      appLauncher = {
        enableClipboardHistory = true;
      };
      theme = "dracula";
      lockscreen = {
        enable = true;
        allowPasswordWithFprintd = true;
      };
      wallpaper.enabled = false;
      location.enable = true;
    };
  };
}
