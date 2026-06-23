{
  inputs,
  pkgs,
  ...
}:
let
  noctaliaShell = inputs.noctalia-shell.packages.${pkgs.system}.default;
  noctaliaLockBeforeSleep = pkgs.replaceVars ./lock-before-sleep.sh {
    noctalia_shell = "${noctaliaShell}/bin/noctalia-shell";
    sleep = "${pkgs.coreutils}/bin/sleep";
  };
in
{
  xdg.configFile."noctalia/colorschemes/Dracula-Custom/Dracula-Custom.json" = {
    source = ./Dracula-Custom.json;
    force = true;
  };

  # Screen-off and suspend on battery only; noctalia handles lock on both AC and battery.
  systemd.user.services.ac-idle-inhibit = {
    Unit = {
      Description = "Screen-off and suspend on battery via swayidle";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      PassEnvironment = "WAYLAND_DISPLAY";
      Environment = "PATH=${
        pkgs.lib.makeBinPath [
          pkgs.swayidle
          pkgs.hyprland
          pkgs.coreutils
          pkgs.systemd
        ]
      }";
      ExecStart = "${pkgs.bash}/bin/bash ${./ac-idle-inhibit.sh}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.noctalia-lock-before-sleep = {
    Unit = {
      Description = "Lock Noctalia before system sleep";
      Before = [ "sleep.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${noctaliaLockBeforeSleep}";
    };
    Install.WantedBy = [ "sleep.target" ];
  };

  xdg.configFile."noctalia/scripts/quit-active-app.sh" = {
    source = ./quit-active-app.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."noctalia/scripts/quit-all-apps.sh" = {
    source = ./quit-all-apps.sh;
    executable = true;
    force = true;
  };

  xdg.desktopEntries.quit-all-apps = {
    name = "Quit All Apps";
    comment = "Close all open windows";
    exec = "${pkgs.bash}/bin/bash -c '\"$HOME/.config/noctalia/scripts/quit-all-apps.sh\"'";
    terminal = false;
    categories = [ "Utility" ];
    icon = "application-exit";
  };

  programs.noctalia-shell = {
    enable = true;
    package = noctaliaShell;

    settings = {
      bar = {
        backgroundOpacity = 0;
        useSeparateOpacity = true;
        capsuleOpacity = 0;
        widgets.left = [
          { id = "Launcher"; }
          {
            id = "Clock";
            formatHorizontal = "yyyy/MM/dd HH:mm:ss";
            formatVertical = "HH mm ss - dd MM";
            tooltipFormat = "yyyy/MM/dd HH:mm:ss";
          }
          {
            id = "SystemMonitor";
            showNetworkStats = true;
            showGpuTemp = true;
          }
          {
            id = "ActiveWindow";
            colorizeIcons = false;
          }
          { id = "MediaMini"; }
        ];
        widgets.center = [
          {
            id = "Workspace";
            labelMode = "index";
            showApplications = true;
            showApplicationsHover = false;
            showBadge = true;
            unfocusedIconsOpacity = 0.55;
          }
        ];
        widgets.right = [
          {
            id = "Tray";
            colorizeIcons = false;
            drawerEnabled = false;
          }
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
          { id = "DarkMode"; }
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
        screenOffTimeout = 0;
        lockTimeout = 300;
        suspendTimeout = 0;
      };
      systemMonitor.enableDgpuMonitoring = true;
      colorSchemes.schedulingMode = "location";
      location.autoLocate = true;
    };
  };
}
