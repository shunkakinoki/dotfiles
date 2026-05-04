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

  # Inhibit idle when plugged into AC; noctalia's idle timeouts apply on battery only.
  systemd.user.services.ac-idle-inhibit = {
    Unit = {
      Description = "Inhibit idle when on AC power";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${./ac-idle-inhibit.sh}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
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
        lockOnSuspend = true;
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
        screenOffTimeout = 300; # 5 min on battery
        lockTimeout = 300;
        suspendTimeout = 600; # 10 min on battery
      };
      systemMonitor.enableDgpuMonitoring = true;
      colorSchemes.schedulingMode = "location";
      location.autoLocate = true;
    };
  };
}
