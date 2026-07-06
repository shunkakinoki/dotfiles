{
  inputs,
  pkgs,
  ...
}:
let
  # v5 renamed the binary noctalia-shell -> noctalia (pname/mainProgram = "noctalia").
  noctalia = inputs.noctalia-shell.packages.${pkgs.system}.default;
  noctaliaLockBeforeSleep = pkgs.replaceVars ./lock-before-sleep.sh {
    noctalia = "${noctalia}/bin/noctalia";
    sleep = "${pkgs.coreutils}/bin/sleep";
  };
  quitAllAppsScript = pkgs.replaceVars ./quit-all-apps-launcher.sh {
    hyprctl = "${pkgs.hyprland}/bin/hyprctl";
    jq = "${pkgs.jq}/bin/jq";
  };
in
{
  # NOTE: v4 shipped a Dracula-Custom colorscheme at noctalia/colorschemes/...
  # v5 replaced colorschemes with a palette/theme system (noctalia/palettes/*.json,
  # different format), so the old file is no longer wired up. Recreate the palette
  # on-device via the v5 settings UI or programs.noctalia.customPalettes.

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

  xdg.desktopEntries.logout = {
    name = "Log Out";
    comment = "End the current session";
    exec = "${noctalia}/bin/noctalia msg session logout";
    terminal = false;
    categories = [ "System" ];
    icon = "system-log-out";
  };

  xdg.desktopEntries.suspend = {
    name = "Suspend";
    comment = "Put the system to sleep";
    exec = "${noctalia}/bin/noctalia msg session suspend";
    terminal = false;
    categories = [ "System" ];
    icon = "system-suspend";
  };

  xdg.desktopEntries.screenshot-region = {
    name = "Screenshot Region";
    comment = "Capture a screen region";
    exec = "${noctalia}/bin/noctalia msg screenshot-region";
    terminal = false;
    categories = [ "Utility" ];
    icon = "accessories-screenshot";
  };

  xdg.desktopEntries.do-not-disturb = {
    name = "Toggle Do Not Disturb";
    comment = "Toggle notification Do Not Disturb mode";
    exec = "${noctalia}/bin/noctalia msg notification-dnd-toggle";
    terminal = false;
    categories = [ "Utility" ];
    icon = "notifications-disabled";
  };

  xdg.desktopEntries.reboot = {
    name = "Reboot";
    comment = "Restart the system";
    exec = "${noctalia}/bin/noctalia msg session reboot";
    terminal = false;
    categories = [ "System" ];
    icon = "system-reboot";
  };

  xdg.desktopEntries.shut-down = {
    name = "Shut Down";
    comment = "Power off the system";
    exec = "${noctalia}/bin/noctalia msg session shutdown";
    terminal = false;
    categories = [ "System" ];
    icon = "system-shutdown";
  };

  xdg.desktopEntries.lock-screen = {
    name = "Lock Screen";
    comment = "Lock the session";
    exec = "${noctalia}/bin/noctalia msg session lock";
    terminal = false;
    categories = [ "System" ];
    icon = "system-lock-screen";
  };

  xdg.desktopEntries.toggle-dark-mode = {
    name = "Toggle Dark Mode";
    comment = "Switch between dark and light theme";
    exec = "${noctalia}/bin/noctalia msg theme-mode-toggle";
    terminal = false;
    categories = [ "Utility" ];
    icon = "weather-clear-night";
  };

  xdg.desktopEntries.quit-all-apps = {
    name = "Quit All Apps";
    comment = "Close all open windows";
    exec = "${pkgs.bash}/bin/bash ${quitAllAppsScript}";
    terminal = false;
    categories = [ "Utility" ];
    icon = "application-exit";
  };

  programs.noctalia = {
    enable = true;
    package = noctalia;

    settings = {
      shell = {
        font_family = "Noto Sans";
        clipboard_enabled = true;
        clipboard_auto_paste = "auto";
        screen_time_enabled = true;
        animation = {
          enabled = true;
          speed = 3;
        };
        panel.transparency_mode = "glass";
      };

      backdrop = {
        enabled = true;
        blur_intensity = 40;
        tint_intensity = 20;
      };

      audio = {
        enable_sounds = false;
        enable_overdrive = true;
      };

      shell.shadow = {
        direction = "down";
        alpha = 0.3;
      };

      nightlight = {
        enabled = true;
        temperature_night = 3500;
      };

      brightness = {
        enable_ddcutil = true;
        sync_all_monitors = true;
        minimum_brightness = 5;
      };

      battery.warning_threshold = 15;

      hot_corners = {
        enabled = true;
        top_left.action = "workspaces";
        top_right.action = "control_center";
        bottom_left.action = "launcher";
        bottom_right.action = "desktop";
      };

      control_center.width = 400;

      theme = {
        mode = "auto";
        source = "builtin";
        builtin = "Dracula";
      };

      bar.main = {
        background_opacity = 0.0;
        margin_ends = 0;
        margin_edge = 0;
        capsule = true;
        capsule_opacity = 0.6;
        shadow = true;
        start = [
          "launcher"
          "clock"
          "cpu"
          "memory"
          "network_rx"
          "network_tx"
          "gpu"
          "active_window"
        ];
        center = [ "workspaces" ];
        end = [
          "tray"
          "bluetooth"
          "network"
          "notification_history"
          "battery"
          "power_profile"
          "volume"
          "brightness"
          "dark_mode"
          "control_center"
        ];
      };

      widget.clock = {
        format = "{:%Y/%m/%d %H:%M:%S}";
        vertical_format = "{:%H %M %S - %d %m}";
        tooltip_format = "{:%Y/%m/%d %H:%M:%S}";
      };

      notification = {
        enable_daemon = true;
        position = "top_right";
        background_opacity = 0.75;
      };

      osd.position = "right";

      lockscreen = {
        enabled = true;
        fingerprint = true;
        blurred_desktop = true;
        blur_intensity = 0.4;
        tint_intensity = 0.2;
      };

      lockscreen_widgets.enabled = true;

      idle = {
        behavior.lock = {
          enabled = true;
          timeout = 300;
          command = "noctalia:session lock";
        };
        behavior.screen-off.enabled = false;
        behavior.suspend.enabled = false;
      };

      system.monitor = {
        enabled = true;
      };

      dock = {
        enabled = true;
        auto_hide = true;
        reserve_space = false;
        magnification = true;
        magnification_scale = 1.4;
        show_running = true;
        icon_size = 48;
        launcher_icon = "nix-snowflake";
      };

      desktop_widgets.enabled = true;
      wallpaper.enabled = false;
      location.auto_locate = true;

      hooks.theme_mode_changed = ''
        if [ "$NOCTALIA_THEME_MODE" = "dark" ]; then
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
  };
}
