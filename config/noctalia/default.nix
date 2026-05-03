{
  inputs,
  pkgs,
  ...
}:
{
  xdg.configFile."noctalia/colorschemes/Dracula-Custom/Dracula-Custom.json" = {
    source = ./Dracula-Custom.json;
    force = true;
  };

  programs.noctalia-shell = {
    enable = true;
    package = inputs.noctalia-shell.packages.${pkgs.system}.default;

    settings = {
      bar = {
        backgroundOpacity = 0;
        useSeparateOpacity = true;
        capsuleOpacity = 0;
        widgets.left = [
          { id = "Launcher"; }
          { id = "Workspaces"; }
          {
            id = "Clock";
            formatHorizontal = "yyyy/MM/dd HH:mm:ss";
          }
          {
            id = "SystemMonitor";
            showNetworkStats = true;
            showGpuTemp = true;
          }
          { id = "ActiveWindow"; }
          { id = "MediaMini"; }
        ];
        widgets.right = [
          { id = "Tray"; }
          { id = "Bluetooth"; }
          { id = "Network"; }
          { id = "NotificationHistory"; }
          {
            id = "Battery";
            displayMode = "graphic";
          }
          { id = "PowerProfile"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
      };
      ui = {
        fontDefault = "Noto Sans";
        fontFixed = "JetBrainsMono Nerd Font";
      };
      notifications = {
        location = "top_right";
        backgroundOpacity = 0.75;
      };
      osd = {
        enabled = true;
        location = "right";
      };
      appLauncher = {
        enableClipboardHistory = true;
        autoPasteClipboard = true;
      };
      general = {
        animationSpeed = 3;
        compactLockScreen = true;
        autoStartAuth = true;
        allowPasswordWithFprintd = true;
      };
      colorSchemes.predefinedScheme = "Dracula-Custom";
      hooks = {
        enabled = true;
        darkModeChange = ''
          if [ "$1" = "true" ]; then
            dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
            dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
            dconf write /org/gnome/desktop/interface/icon-theme "'Adwaita'"
          else
            dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
            dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita'"
            dconf write /org/gnome/desktop/interface/icon-theme "'Adwaita'"
          fi
        '';
      };
      dock = {
        colorizeIcons = true;
        showLauncherIcon = true;
        showDockIndicator = false;
      };
      desktopWidgets.enabled = true;
      wallpaper.enabled = false;
      idle = {
        enabled = true;
        timeout = 300;
      };
      systemMonitor.enableDgpuMonitoring = true;
      colorSchemes.schedulingMode = "location";
      location.autoLocate = true;
    };
  };
}
