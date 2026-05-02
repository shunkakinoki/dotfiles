{
  inputs,
  pkgs,
  ...
}:
{
  xdg.configFile."noctalia/colorschemes/Dracula-Custom/Dracula-Custom.json".text = builtins.toJSON {
    dark = {
      mPrimary = "#bd93f9";
      mOnPrimary = "#282A36";
      mSecondary = "#ff79c6";
      mOnSecondary = "#4e1d32";
      mTertiary = "#8be9fd";
      mOnTertiary = "#003543";
      mError = "#FF5555";
      mOnError = "#282A36";
      mSurface = "#282A36";
      mOnSurface = "#F8F8F2";
      mSurfaceVariant = "#44475A";
      mOnSurfaceVariant = "#d6d8e0";
      mOutline = "#5a5e77";
      mShadow = "#282A36";
      mHover = "#8be9fd";
      mOnHover = "#003543";
      terminal = {
        normal = { black = "#21222c"; red = "#ff5555"; green = "#50fa7b"; yellow = "#f1fa8c"; blue = "#bd93f9"; magenta = "#ff79c6"; cyan = "#8be9fd"; white = "#f8f8f2"; };
        bright = { black = "#6272a4"; red = "#ff6e6e"; green = "#69ff94"; yellow = "#ffffa5"; blue = "#d6acff"; magenta = "#ff92df"; cyan = "#a4ffff"; white = "#ffffff"; };
        foreground = "#f8f8f2";
        background = "#282a36";
        selectionFg = "#ffffff";
        selectionBg = "#44475a";
        cursorText = "#282a36";
        cursor = "#f8f8f2";
      };
    };
    light = {
      mPrimary = "#8332f4";
      mOnPrimary = "#ffffff";
      mSecondary = "#ff1399";
      mOnSecondary = "#ffffff";
      mTertiary = "#0398b9";
      mOnTertiary = "#ffffff";
      mError = "#FF5555";
      mOnError = "#282A36";
      mSurface = "#f8f8f2";
      mOnSurface = "#F8F8F2";
      mSurfaceVariant = "#e6e6ea";
      mOnSurfaceVariant = "#d6d8e0";
      mOutline = "#cacad3";
      mShadow = "#d6d8e0";
      mHover = "#0398b9";
      mOnHover = "#ffffff";
      terminal = {
        normal = { black = "#f8f8f2"; red = "#ff5555"; green = "#50fa7b"; yellow = "#f1fa8c"; blue = "#bd93f9"; magenta = "#ff79c6"; cyan = "#8be9fd"; white = "#282a36"; };
        bright = { black = "#6272a4"; red = "#ff6e6e"; green = "#69ff94"; yellow = "#ffffa5"; blue = "#d6acff"; magenta = "#ff92df"; cyan = "#a4ffff"; white = "#000000"; };
        foreground = "#282a36";
        background = "#ffffff";
        selectionFg = "#ffffff";
        selectionBg = "#6272a4";
        cursorText = "#ffffff";
        cursor = "#282a36";
      };
    };
  };

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
        backgroundOpacity = 0.75;
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
      colorSchemes.predefinedScheme = "Dracula-Custom";
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
      systemMonitor.enableDgpuMonitoring = true;
      colorSchemes.schedulingMode = "location";
      location.autoLocate = true;
    };
  };
}
