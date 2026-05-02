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
        battery.showLabel = true;
        network.showLabel = false;
        bluetooth.showLabel = false;
        transparent = true;
        capsuleOpacity = 0;
        workspaces = {
          showIcons = true;
          showApplicationIcons = true;
          numberedActiveIndicator = "underline";
        };
        widgets.left = [
          { id = "Launcher"; }
          { id = "Clock"; formatHorizontal = "yyyy/MM/dd HH:mm:ss"; }
          { id = "SystemMonitor"; showNetworkStats = true; }
          { id = "ActiveWindow"; }
          { id = "MediaMini"; }
        ];
        widgets.right = [
          { id = "Tray"; }
          { id = "Bluetooth"; }
          { id = "Network"; }
          { id = "NotificationHistory"; }
          { id = "Battery"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
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
        enabled = true;
        orientation = "vertical";
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
      colorSchemes.predefinedScheme = "Dracula";
      hooks = {
        enabled = true;
        darkModeChange = ''if [ "$1" = "true" ]; then dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" && dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"; else dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'" && dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita'"; fi'';
      };
      dock = {
        colorizeIcons = true;
        showLauncherIcon = true;
        showDockIndicator = true;
      };
      desktopWidgets.enabled = true;
      wallpaper.enabled = false;
      idle.enabled = true;
      colorSchemes.schedulingMode = "location";
      location = {
        autoLocate = true;
        weatherTaliaMascotAlways = true;
      };
    };
  };
}
