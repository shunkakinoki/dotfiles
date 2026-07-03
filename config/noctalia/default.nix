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

    # v5 is a ground-up rewrite (C++/Qt, TOML config, snake_case keys) and upstream
    # does NOT migrate v4 settings - "v5 ships with sane defaults, customize from there".
    # The v4 config (bar widget layout, Dracula theme, dark-mode dconf hook, idle
    # timeouts, per-widget options) has NO mechanical v5 equivalent and its semantics
    # changed (e.g. bar widgets are now id vectors + separate styling; idle uses a
    # behavior map; hooks run with no args). Re-apply those on-device via the settings UI.
    #
    # Only keys verified against the v5 schema (src/config/schema/config_schema.cpp)
    # are set here so the build-time `noctalia config validate` passes.
    settings = {
      shell = {
        font_family = "Noto Sans"; # was ui.fontDefault
        clipboard_enabled = true; # was appLauncher.enableClipboardHistory
        clipboard_auto_paste = "auto"; # was appLauncher.autoPasteClipboard = true
      };
      location.auto_locate = true; # was location.autoLocate
      wallpaper.enabled = false; # noctalia does not manage the wallpaper (wallpaper engine does)
    };
  };
}
